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
    func translate123Json() {
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
}
