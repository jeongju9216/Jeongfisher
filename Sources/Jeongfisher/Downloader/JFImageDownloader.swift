//
//  JFImageDownloader.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/14.
//

import UIKit

public enum JeongNetworkError: Error {
    case apiError
    case imageDownloadError
    case alreadyExistSessionError
    case urlError
}

/// URL을 이용한 이미지 다운로드
public final actor JFImageDownloader: JFImageDownloadable {
    public static let shared: JFImageDownloader = JFImageDownloader()
    
    private init() { }
    
    /// Task 상태
    private enum DownloadEntry {
        case inProgress(Task<JFImageData, Error>)
        case ready(JFImageData)
    }
    
    private var cache: [URL: DownloadEntry] = [:]
    
    /// URL 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - eTag: 이미지 eTag
    /// - Returns: 이미지 다운로드 결과
    public func downloadImage(from url: URL, eTag: String? = nil) async throws -> JFImageData {
        //이미 같은 URL 요청이 들어온 경우 Task 완료 대기
        if let cached = cache[url] {
            switch cached {
            case .inProgress(let task):
                return try await task.value
            case .ready(let jfImageData):
                return jfImageData
            }
        }
        
        let task = Task {
            try await download(url: url, eTag: eTag)
        }
        
        cache[url] = .inProgress(task)
        
        do {
            let jfImageData = try await task.value
            cache[url] = .ready(jfImageData)
            return jfImageData
        } catch {
            cache[url] = nil
            throw error
        }
    }
    
    /// URL 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - eTag: 이미지 eTag
    /// - Returns: 이미지 다운로드 결과
    private func download(url: URL, eTag: String? = nil) async throws -> JFImageData {
        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            if let eTag = eTag {
                request.addValue(eTag, forHTTPHeaderField: "If-None-Match")
            }
            
            let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    continuation.resume(with: .failure(error))
                    return
                }
                
                guard let httpURLResponse = response as? HTTPURLResponse, (200..<400) ~= httpURLResponse.statusCode,
                      let data = data else {
                    continuation.resume(with: .failure(JeongNetworkError.imageDownloadError))
                    return
                }
                                
                let eTag: String = httpURLResponse.allHeaderFields["Etag"] as? String ?? ""
                let imageFormat: JFImageFormat = url.absoluteString.getJFImageFormatFromURLString()
                
                let imageData = JFImageData(data: data, eTag: eTag, imageExtension: imageFormat)
                
                continuation.resume(with: .success(imageData))
            }
            
            task.resume()
        }
    }
    
    /// URL 이미지 다운로드 취소
    /// - Parameter url: 취소할 이미지 URL
    public func cancelDownloadImage(url: URL) async {
        guard let cached = cache[url] else { return }
        
        switch cached {
        case .inProgress(let task):
            if !task.isCancelled {
                task.cancel()
            }
        default: return
        }
    }
}
