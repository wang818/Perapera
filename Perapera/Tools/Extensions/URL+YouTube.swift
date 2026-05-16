import Foundation

extension URL {
    /// 从 YouTube URL 中提取视频 ID
    /// 支持格式：
    /// - https://www.youtube.com/watch?v=VIDEO_ID
    /// - https://youtu.be/VIDEO_ID
    /// - https://youtube.com/shorts/VIDEO_ID
    /// - https://www.youtube.com/embed/VIDEO_ID
    var youtubeVideoID: String? {
        guard absoluteString.contains("youtube") || absoluteString.contains("youtu.be") else {
            return nil
        }

        // youtube.com/watch?v=VIDEO_ID
        if absoluteString.contains("youtube.com") {
            if let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                if let v = queryItems.first(where: { $0.name == "v" })?.value {
                    return v
                }
            }
            // youtube.com/embed/VIDEO_ID 或 youtube.com/shorts/VIDEO_ID
            let pathComponents = pathComponents
            for component in pathComponents {
                if component.count == 11, !component.contains(".") {
                    return component
                }
            }
        }

        // youtu.be/VIDEO_ID
        if absoluteString.contains("youtu.be") {
            let lastComponent = lastPathComponent
            if lastComponent.count == 11 || lastComponent.contains("?") {
                return lastComponent.components(separatedBy: "?").first
            }
            return lastComponent
        }

        return nil
    }
}

extension String {
    /// 从 YouTube URL 字符串中提取视频 ID
    var youtubeVideoID: String? {
        guard let url = URL(string: self) else { return nil }
        return url.youtubeVideoID
    }
}
