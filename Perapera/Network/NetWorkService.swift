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
        /// use  defaultAlamofireSession as original when init, so here use the same parameters as the default one, then add the monitor to collect metrics
        let session = Session(configuration: internalSession.sessionConfiguration, startRequestsImmediately: internalSession.startImmediately, eventMonitors: [monitor])
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
    let method = target.method
    
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
