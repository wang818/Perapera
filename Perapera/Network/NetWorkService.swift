//
//  NetWorkService.swift
//  Perapera
//
//  Adapted for Perapera
//

import Moya
import RxSwift
import Alamofire
import Foundation

extension Notification.Name {
    /// 后端 API 返回 401 时广播的通知（refresh 失败后也会广播）
    static let peraperaAPIUnauthorized = Notification.Name("PeraperaAPIUnauthorized")
}

/// 鉴权 401 时的请求重试器：
/// 1. 先调用 /auth/refresh 拿新 token
/// 2. 成功：更新 token 后重发原请求（仅一次）
/// 3. 失败：广播 peraperaAPIUnauthorized 通知 UI 弹登录页
final class AuthRefreshRetrier: RequestInterceptor {
    private let lock = NSLock()
    private var isRefreshing = false
    private var pendingRetries: [(RetryResult) -> Void] = []

    func retry(_ request: Alamofire.Request,
               for session: Alamofire.Session,
               dueTo error: Error,
               completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        // 已经是 refresh 请求本身失败，不再重试
        if let url = request.request?.url?.path, url.hasSuffix("/auth/refresh") {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .peraperaAPIUnauthorized, object: nil)
            }
            completion(.doNotRetry)
            return
        }

        // 单飞：所有 401 共享同一次 refresh
        lock.lock()
        pendingRetries.append(completion)
        if isRefreshing {
            lock.unlock()
            return
        }
        isRefreshing = true
        lock.unlock()

        _ = AuthRefreshService.shared.refreshIfNeeded()
            .subscribe(onSuccess: { [weak self] _ in
                self?.lock.lock()
                let waiters = self?.pendingRetries ?? []
                self?.pendingRetries.removeAll()
                self?.isRefreshing = false
                self?.lock.unlock()
                waiters.forEach { $0(.retry) }
            }, onFailure: { [weak self] _ in
                self?.lock.lock()
                let waiters = self?.pendingRetries ?? []
                self?.pendingRetries.removeAll()
                self?.isRefreshing = false
                self?.lock.unlock()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .peraperaAPIUnauthorized, object: nil)
                }
                waiters.forEach { $0(.doNotRetry) }
            })
    }
}

class NetWorkService<Target> : MoyaProvider<Target> where Target : TargetType {

    var plugin: MoyaLoadingPlugin?
    ///
    let monitor: ClosureEventMonitor = {
        let monitor = ClosureEventMonitor()
        monitor.taskDidFinishCollectingMetrics = { (session:URLSession, task:URLSessionTask, metrics:URLSessionTaskMetrics) in
            guard task.state == .completed, let urlString = task.originalRequest?.url?.absoluteString else { return }
            let error = task.error?.localizedDescription ?? ""
            let errorCode = (task.error as? NSError)?.code.description ?? ""
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode.description ?? ""
            let duration = CLong(round(metrics.taskInterval.duration * 1000))
            let parameters = ["url":urlString,
                              "duration":duration.description,
                              "statusCode":statusCode,
                              "error":error,
                              "errorCode":errorCode]
            EXTracking.shared.track(event: .httpTrack, info: parameters)
            if duration > 400 {
                EXTracking.shared.track(event: .httpTrackLow, info: parameters)
            }
            // 401 由 AuthRefreshRetrier 走 refresh 流程
        }
        return monitor
    }()
    ///
    init(
        endpointClosure: @escaping MoyaProvider<Target>.EndpointClosure = MoyaProvider.defaultEndpointMapping,
        requestClosure: @escaping MoyaProvider<Target>.RequestClosure,
        stubClosure: @escaping MoyaProvider<Target>.StubClosure = MoyaProvider.neverStub,
        plugins: [PluginType] = [MoyaLoadingPlugin() as PluginType]
    ) {
        let internalSession = MoyaProvider<Target>.defaultAlamofireSession()
        let retrier = AuthRefreshRetrier()
        let session = Alamofire.Session(configuration: internalSession.sessionConfiguration,
                              startRequestsImmediately: internalSession.startImmediately,
                                        interceptor: retrier, eventMonitors: [monitor])
        super.init(endpointClosure: endpointClosure,
                   requestClosure: requestClosure,
                   stubClosure: stubClosure,
                   session: session,
                   plugins: plugins)
        plugin = plugins[0] as? MoyaLoadingPlugin
    }
    
    func hideAutoLoading() {
        plugin?.noloading()
    }
    
    func showAutoLoading() {
        plugin?.showloading()
    }
}

let requestClosure: MoyaProvider<AppAPIEndPoint>.RequestClosure = {( endpoint: Endpoint, closure: MoyaProvider.RequestResultClosure) in
    do {
        let urlRequest = try endpoint.urlRequest()
        closure(.success(urlRequest))
    }
    catch {
        
    }
}

let appApiEndpointClosure = { (target: AppAPIEndPoint) -> Endpoint in
    let sampleResponseClosure = { return EndpointSampleResponse.networkResponse(200, target.sampleData) }
    let url = target.baseURL.appendingPathComponent(target.path).absoluteString

    return Endpoint(url: url, sampleResponseClosure: sampleResponseClosure, method: target.method, task: target.task, httpHeaderFields: target.headers)
}

/*
let contractApiEndpointClosure = { (target: ContractAPIEndPoint) -> Endpoint in
    let sampleResponseClosure = { return EndpointSampleResponse.networkResponse(200, target.sampleData) }
    let url = target.baseURL.appendingPathComponent(target.path).absoluteString
    let method = target.method
    
    return Endpoint(url: url,
                    sampleResponseClosure: sampleResponseClosure,
                    method: target.method,
                    task: target.task,
                    httpHeaderFields: target.headers)
}
*/


/*
let otcApiEndpointClosure = { (target: OTCAPIEndPoint) -> Endpoint in
    let sampleResponseClosure = { return EndpointSampleResponse.networkResponse(200, target.sampleData) }
    let url = target.baseURL.appendingPathComponent(target.path).absoluteString
    let method = target.method
    
    return Endpoint(url: url,
                    sampleResponseClosure: sampleResponseClosure,
                    method: target.method,
                    task: target.task,
                    httpHeaderFields: target.headers)
}

let redPacketAPIEndpointClosure = { (target: RedPacketAPIEndPoint) -> Endpoint in
    let sampleResponseClosure = { return EndpointSampleResponse.networkResponse(200, target.sampleData) }
    let url = target.baseURL.appendingPathComponent(target.path).absoluteString
    let method = target.method
    
    return Endpoint(url: url,
                    sampleResponseClosure: sampleResponseClosure,
                    method: target.method,
                    task: target.task,
                    httpHeaderFields: target.headers)
}
*/

let appApi = NetWorkService(endpointClosure: appApiEndpointClosure, requestClosure: requestClosure)

/*
let contractApi = NetWorkService(endpointClosure: contractApiEndpointClosure, requestClosure: requestClosure)
*/


/*
let otcApi = NetWorkService(endpointClosure: otcApiEndpointClosure, requestClosure: requestClosure)

let redPacketApi = NetWorkService(endpointClosure: redPacketAPIEndpointClosure, requestClosure: requestClosure)

let domainSpeedTestApi = NetWorkService<EXDomainSpeedTestEndPoint>(requestClosure: requestClosure)

let newContractApi = NetWorkService<EXContractApiEndPoint>(requestClosure: requestClosure)
*/
