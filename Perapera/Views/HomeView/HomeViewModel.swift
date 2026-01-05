//
//  HomeViewModel.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import RxSwift
import Moya
import HandyJSON

class HomeViewModel: ObservableObject {
    private let disposeBag = DisposeBag()
    
    func getZendeskNotice() {
        print("Start requesting Zendesk Notice...")
        appApi.rx.request(AppAPIEndPoint.zendeskNotice(page: "1", pagesize: "10"))
            .asObservable()
            .mapObject(EXZendeskNoticeModel.self)
            .subscribe(onNext: { entity in
                print("✅ Zendesk Notice Success: count=\(entity.count)")
                for item in entity.noticeInfoList {
                    print("Title: \(item.title)")
                }
            }, onError: { error in
                print("❌ Zendesk Notice Failure: \(error.localizedDescription)")
            })
            .disposed(by: disposeBag)
    }
}
