//
//  YTBasicInfoModel.swift
//  Perapera
//

import Foundation
import HandyJSON

/// 视频基本信息（yt_audio 接口返回的原始元数据）
class YTBasicInfoModel: HandyJSON {
    var video_id: String = ""
    var title: String = ""
    var author: String = ""
    var number_of_views: String = ""
    var video_length: String = ""
    var description: String = ""
    var is_live_content: Bool = false
    var published_time: String = ""
    var channel_id: String = ""
    var category: String = ""
    var type: String = ""
    var keywords: [String] = []
    var thumbnails: [YTThumbnailModel] = []

    required init() {}

    /// 选中等尺寸的一张缩略图作为封面（thumbnails[3]，336x188）
    var bestThumbnail: YTThumbnailModel? {
        // 优先取 thumbnails[3]（API 返回的 336x188 那张），没有就按索引兜底
        if thumbnails.count >= 4 {
            return thumbnails[3]
        }
        // 兜底：取最大一张
        return thumbnails.max(by: { ($0.width * $0.height) < ($1.width * $1.height) })
    }

    /// 视频时长（秒，video_length 是秒数字符串）
    var durationSeconds: Int {
        Int(video_length) ?? 0
    }
}

class YTThumbnailModel: HandyJSON {
    var url: String = ""
    var width: Int = 0
    var height: Int = 0

    required init() {}
}
