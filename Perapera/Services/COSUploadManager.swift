//
//  COSUploadManager.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import QCloudCOSXML

class COSUploadManager: NSObject {
    
    static let shared = COSUploadManager()
    
    private var cosService: QCloudCOSXMLService?
    private var cosTransferManager: QCloudCOSTransferMangerService?
    
    private override init() {
        super.init()
        setupCOS()
    }
    
    // MARK: - Setup
    
    private func setupCOS() {
        // 确保本地凭证已加载
        #if DEBUG
        COSConfig.setupLocalCredentials()
        #endif
        
        let config = QCloudServiceConfiguration()
        config.signatureProvider = self
        config.appID = COSConfig.bucket.components(separatedBy: "-").last ?? ""
        
        let endpoint = QCloudCOSXMLEndPoint()
        endpoint.regionName = COSConfig.region
        endpoint.useHTTPS = true
        config.endpoint = endpoint
        
        QCloudCOSXMLService.registerDefaultCOSXML(with: config)
        QCloudCOSTransferMangerService.registerDefaultCOSTransferManger(with: config)
        
        self.cosService = QCloudCOSXMLService.defaultCOSXML()
        self.cosTransferManager = QCloudCOSTransferMangerService.defaultCOSTransferManager()
    }
    
    // MARK: - Upload Methods
    
    /// 上传文件到腾讯云COS
    /// - Parameters:
    ///   - fileURL: 本地文件URL
    ///   - progress: 上传进度回调
    ///   - completion: 完成回调，返回COS访问URL或错误
    func uploadFile(
        fileURL: URL,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 兼容两类 URL：
        // 1. 文件选择器/相册返回的外部 URL（需要 start/stop 安全作用域）
        // 2. App 自身 Documents 目录下的 URL（没有安全作用域，直接读即可）
        let isScoped = fileURL.startAccessingSecurityScopedResource()
        let shouldReleaseScope = isScoped

        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            if shouldReleaseScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
            completion(.failure(NSError(domain: "COSUploadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问文件"])))
            return
        }

        let fileName = fileURL.lastPathComponent
        let objectKey = COSConfig.generateObjectKey(fileName: fileName)

        let uploadRequest = QCloudCOSXMLUploadObjectRequest<AnyObject>()
        uploadRequest.bucket = COSConfig.bucket
        uploadRequest.object = objectKey
        uploadRequest.body = fileURL as NSURL

        uploadRequest.sendProcessBlock = { bytesSent, totalBytesSent, totalBytesExpectedToSend in
            let progressValue = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            DispatchQueue.main.async {
                progress?(progressValue)
            }
        }

        let releaseScope: () -> Void = { [shouldReleaseScope] in
            if shouldReleaseScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        uploadRequest.setFinish { _, error in
            releaseScope()
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ COS上传失败: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    let accessURL = COSConfig.generateAccessURL(objectKey: objectKey)
                    print("✅ COS上传成功: \(accessURL)")
                    completion(.success(accessURL))
                }
            }
        }

        self.cosTransferManager?.uploadObject(uploadRequest)
    }
    
    /// 批量上传文件
    /// - Parameters:
    ///   - fileURLs: 本地文件URL数组
    ///   - progress: 总体上传进度回调
    ///   - completion: 完成回调，返回所有文件的COS访问URL或错误
    func uploadFiles(
        fileURLs: [URL],
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        var uploadedURLs: [String] = []
        var totalProgress: Double = 0
        let totalFiles = Double(fileURLs.count)
        
        let group = DispatchGroup()
        var uploadError: Error?
        
        for (index, fileURL) in fileURLs.enumerated() {
            group.enter()
            
            uploadFile(fileURL: fileURL, progress: { fileProgress in
                totalProgress = (Double(index) + fileProgress) / totalFiles
                progress?(totalProgress)
            }) { result in
                switch result {
                case .success(let url):
                    uploadedURLs.append(url)
                case .failure(let error):
                    uploadError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = uploadError {
                completion(.failure(error))
            } else {
                completion(.success(uploadedURLs))
            }
        }
    }
}

// MARK: - QCloudSignatureProvider

extension COSUploadManager: QCloudSignatureProvider {
    
    func signature(with fileds: QCloudSignatureFields!, request: QCloudBizHTTPRequest!, urlRequest: NSMutableURLRequest!, compelete: QCloudHTTPAuthentationContinueBlock!) {
        
        // 确保 continueBlock 不为空
        guard let continueBlock = compelete else {
            print("❌ ContinueBlock is nil")
            return
        }
        
        // 获取凭证
        let secretId = COSConfig.secretId
        let secretKey = COSConfig.secretKey
        
        print("🔑 SecretId: \(secretId.isEmpty ? "空" : "已设置")")
        print("🔑 SecretKey: \(secretKey.isEmpty ? "空" : "已设置")")
        
        // 检查凭证是否为空
        guard !secretId.isEmpty, !secretKey.isEmpty else {
            print("❌ SecretId 或 SecretKey 为空")
            let error = NSError(domain: "COSUploadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "SecretId 或 SecretKey 未配置"])
            continueBlock(nil, error)
            return
        }
        
        // 创建凭证对象
        let credential = QCloudCredential()
        credential.secretID = secretId
        credential.secretKey = secretKey
        
        // 生成签名
        let creator = QCloudAuthentationV5Creator(credential: credential)
        guard let signature = creator?.signature(forData: urlRequest) else {
            print("❌ 签名生成失败")
            let error = NSError(domain: "COSUploadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "签名生成失败"])
            continueBlock(nil, error)
            return
        }
        
        print("✅ 签名生成成功")
        continueBlock(signature, nil)
    }
}
