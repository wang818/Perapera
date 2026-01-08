//
//  COSUploadManager.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import QCloudCOSXML

class COSUploadManager {
    
    static let shared = COSUploadManager()
    
    private var cosService: QCloudCOSXMLService?
    private var cosTransferManager: QCloudCOSTransferMangerService?
    
    private init() {
        setupCOS()
    }
    
    // MARK: - Setup
    
    private func setupCOS() {
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
        self.cosTransferManager = QCloudCOSTransferMangerService.defaultCOSTransferManger()
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
        guard fileURL.startAccessingSecurityScopedResource() else {
            completion(.failure(NSError(domain: "COSUploadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问文件"])))
            return
        }
        
        defer {
            fileURL.stopAccessingSecurityScopedResource()
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
        
        uploadRequest.setFinish { [weak self] outputObject, error in
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
        
        let credential = QCloudCredential()
        credential.secretID = COSConfig.secretId
        credential.secretKey = COSConfig.secretKey
        
        let creator = QCloudAuthentationV5Creator(credential: credential)
        let signature = creator?.signature(forData: urlRequest)
        
        compelete(signature, nil)
    }
}
