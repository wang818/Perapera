//
//  HomeViewModel.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation

class HomeViewModel: ObservableObject {
    @Published var isTranslating: Bool = false
    @Published var translationResult: String = ""
    @Published var translationError: String?
    
    /// 翻译 123.json 文件
    func translate123Json(videoId: String? = nil) {
        guard let path = Bundle.main.path(forResource: "123", ofType: "json"),
              let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            translationError = "无法读取 123.json 文件"
            print("❌ 无法读取 123.json 文件")
            return
        }
        
        print("\n" + String(repeating: "🌟", count: 40))
        print("🚀 开始翻译 123.json")
        print(String(repeating: "🌟", count: 40) + "\n")
        
        isTranslating = true
        translationError = nil
        
        HunyuanManager.shared.translateWordsToJapanese(jsonData: jsonData) { [weak self] result in
            DispatchQueue.main.async {
                self?.isTranslating = false
                
                switch result {
                case .success(let translatedData):
                    if let jsonString = String(data: translatedData, encoding: .utf8) {
                        print("\n" + String(repeating: "=", count: 80))
                        print("📄 完整的翻译后 JSON 数据")
                        print(String(repeating: "=", count: 80))
                        print(jsonString)
                        print(String(repeating: "=", count: 80) + "\n")
                        
                        self?.translationResult = jsonString
                        
                        // 保存翻译结果为 txt 文件到 Documents 目录
                        self?.saveTranslationResultToTxt(jsonString: jsonString, videoId: videoId)
                    }
                    
                case .failure(let error):
                    print("\n" + String(repeating: "=", count: 80))
                    print("❌ 翻译失败")
                    print(String(repeating: "=", count: 80))
                    print("错误信息: \(error.localizedDescription)")
                    print(String(repeating: "=", count: 80) + "\n")
                    
                    self?.translationError = error.localizedDescription
                    self?.translationResult = "翻译失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 保存翻译结果为 txt 文件到 Documents 目录
    private func saveTranslationResultToTxt(jsonString: String, videoId: String?) {
        do {
            // 获取 Documents 目录
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // 生成文件名：如果有 videoId 则使用 videoId_translation.txt，否则使用时间戳
            let fileName: String
            if let videoId = videoId {
                fileName = "\(videoId)_translation.txt"
            } else {
                let timestamp = Int(Date().timeIntervalSince1970)
                fileName = "translation_\(timestamp).txt"
            }
            
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            // 写入文件
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            
            print("\n" + String(repeating: "=", count: 60))
            print("💾 翻译结果已保存为 TXT 文件")
            print(String(repeating: "=", count: 60))
            print("📝 文件名: \(fileName)")
            print("📂 文件路径: \(fileURL.path)")
            print("📄 内容长度: \(jsonString.count) 字符")
            print(String(repeating: "=", count: 60) + "\n")
            
        } catch {
            print("❌ 保存翻译结果 TXT 文件失败: \(error.localizedDescription)")
        }
    }
}
