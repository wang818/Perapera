//
//  AuthRefreshService.swift
//  Perapera
//
//  负责在任意业务接口返回 401 时，调用 /auth/refresh 刷新 token。
//  同一时间只发一个 refresh 请求（单飞），其他并发请求会等待结果。
//

import Foundation
import RxSwift
import Moya

extension Notification.Name {
    /// refresh token 失败后由 NetWorkService 广播，UI 层弹登录页
    static let peraperaAuthRefreshFailed = Notification.Name("PeraperaAuthRefreshFailed")
    /// 业务层（播放页等）请求弹出 LoginView
    static let peraperaRequestShowLogin = Notification.Name("PeraperaRequestShowLogin")
    /// 业务层（+ 按钮等）请求弹出 AI / 第三方数据共享授权弹窗
    static let peraperaRequestAIConsent = Notification.Name("PeraperaRequestAIConsent")
}

final class AuthRefreshService {
    static let shared = AuthRefreshService()

    private let lock = NSLock()
    private var inFlight: Observable<String>?
    private var continuations: [(Result<String, Error>) -> Void] = []

    private init() {}

    /// 尝试刷新 token，成功返回新 token，失败返回 error
    func refreshIfNeeded() -> Single<String> {
        lock.lock()
        let observable: Observable<String>
        if let existing = inFlight {
            observable = existing
            lock.unlock()
            return observable.asSingle()
        }

        let o = Observable<String>.create { [weak self] observer in
            guard let self = self else {
                observer.onError(NSError(domain: "AuthRefreshService", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "AuthRefreshService 已释放"]))
                return Disposables.create()
            }

            self.lock.lock()
            self.continuations.append { result in
                switch result {
                case .success(let token): observer.onNext(token); observer.onCompleted()
                case .failure(let error): observer.onError(error)
                }
            }
            let isFirst = self.continuations.count == 1
            self.lock.unlock()

            if isFirst {
                // 第一个进来的人真正去打 refresh
                self.startRefresh()
            }
            return Disposables.create()
        }
        .share(replay: 1, scope: .whileConnected)

        inFlight = o
        lock.unlock()
        return o.asSingle()
    }

    private func startRefresh() {
        let provider = MoyaProvider<AppAPIEndPoint>(plugins: [MoyaLoadingPlugin() as PluginType])
        provider.request(.refreshAccessToken) { [weak self] result in
            guard let self = self else { return }

            let newToken: String?
            switch result {
            case .success(let response):
                if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                    if let data = json["data"] as? [String: Any],
                       let access = data["access_token"] as? String,
                       !access.isEmpty {
                        newToken = access
                    } else if let access = json["access_token"] as? String,
                              !access.isEmpty {
                        newToken = access
                    } else {
                        newToken = nil
                    }
                } else {
                    newToken = nil
                }
            case .failure:
                newToken = nil
            }

            self.lock.lock()
            let waiters = self.continuations
            self.continuations.removeAll()
            self.inFlight = nil
            self.lock.unlock()

            if let token = newToken {
                self.persistToken(token)
                waiters.forEach { $0(.success(token)) }
            } else {
                let error = NSError(domain: "AuthRefreshService", code: 401,
                                     userInfo: [NSLocalizedDescriptionKey: "refresh token 失败"])
                // 通知 UI 层弹登录页
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .peraperaAuthRefreshFailed, object: nil)
                }
                waiters.forEach { $0(.failure(error)) }
            }
        }
    }

    private func persistToken(_ token: String) {
        // 1) 写到 UserDefaults（原始存）
        PUserDefault.setValueForKey(token, key: "access_token")

        // 2) 更新 UserManager.currentUser，保持内存一致
        if var user = UserManager.shared.currentUser {
            user.access_token = token
            UserManager.shared.save(model: user, email: UserManager.shared.userEmail ?? "")
        }
    }
}
