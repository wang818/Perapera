//
//  EXZendeskNoticeModel.swift
//  Perapera
//
//  Adapted for Perapera
//

import Foundation
import HandyJSON

class EXZendeskNoticeModel: HandyJSON {
    var count: String = ""
    var noticeInfoList: [EXZendeskNoticeItem] = []
    var page: String = ""
    var pageSize: String = ""
    var zendeskUrl: String = ""
    
    required init() {}
}

class EXZendeskNoticeItem: HandyJSON {
    var typeParentId: String = ""
    var title: String = ""
    var timelong : String = ""
    var sortId : String = ""
    var content: String = ""
    var ctime: String = ""
    var mtime: String = ""
    var stime: String = ""
    var lang: String = ""
    var httpUrl: String = ""
    var id : String = ""
    
    required init() {}
}
