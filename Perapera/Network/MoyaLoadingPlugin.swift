//
//  MoyaLoadingPlugin.swift
//  Perapera
//
//  Adapted for Perapera
//

import Foundation
import Moya

// Define protocol here since EXKit is not available
protocol EXRequestLoadingable {
    var isLoadingable: Bool { get }
}

public final class MoyaLoadingPlugin: PluginType {
    
    // Simple struct to replace LoadingStatusModel
    class LoadingStatusModel: Equatable {
        static func == (lhs: MoyaLoadingPlugin.LoadingStatusModel, rhs: MoyaLoadingPlugin.LoadingStatusModel) -> Bool {
            return lhs.identifer == rhs.identifer
        }
        var identifer: String = ""
        var loading: Bool = false
    }
    
    private var loadings: Array<LoadingStatusModel> = []
    var needLoading: Bool = true
    
    // Stub for ContractPath
    struct ContractPath {
        static let userposition = "user_position"
        static let liquidation = "get_liquidation_rate"
        static let orderlist = "order_list"
        static let tagprice = "tag_price"
        static let takeinitorder = "init_take_order"
    }
    
    func backgroudLoadingList() -> [String] {
        return [ContractPath.userposition,
                ContractPath.liquidation,
                ContractPath.orderlist,
                ContractPath.tagprice,
                ContractPath.takeinitorder]
    }
    
    func noloading() {
        needLoading = false
    }
    
    func showloading() {
        needLoading = true
    }
    
    func backgroudLoadingList(path: String) -> Bool {
        if backgroudLoadingList().contains(path) {
            return true
        }
        return false
    }
    
    public func willSend(_ request: RequestType, target: TargetType) {
        if let request = target as? EXRequestLoadingable, !request.isLoadingable { return }
        
        // Simplified check for AppAPIEndPoint, avoiding specific cases for now
        if let _ = target as? AppAPIEndPoint {
            // Add specific cases here if needed
        }
        
        if self.needLoading {
            if !self.backgroudLoadingList(path: target.path) {
                let model = LoadingStatusModel()
                model.identifer = target.baseURL.absoluteString + target.path
                loadings.append(model)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                    if self.loadings.contains(where: { $0.identifer == model.identifer }) {
                        model.loading = true
                        XHUDManager.sharedInstance.loading()
                    }
                }
            }
        }
    }
    
    public func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        if let request = target as? EXRequestLoadingable, !request.isLoadingable { return }
        // let key = target.baseURL.absoluteString + target.path
        self.needLoading = true
        if !self.backgroudLoadingList(path: target.path) {
            var rmIdx = -1
            for (index, model) in loadings.enumerated() {
                let iden = target.baseURL.absoluteString + target.path
                if model.identifer == iden {
                    rmIdx = index
                    break
                }
            }
            if rmIdx >= 0, loadings.count > rmIdx {
                loadings.remove(at: rmIdx)
            }
            XHUDManager.sharedInstance.dismissWithDelay {}
        }
    }
}
