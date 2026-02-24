//
//  SendCaptchaModel.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import HandyJSON

class SendCaptchaModel: HandyJSON {
    var detail: String = ""
    // 如果后续有其他字段，可以在这里添加
    // 注意：statusCode, duration 等是网络库的 Log 字段，不是 API 返回字段，请勿在此定义
    
    required init() {}
}
