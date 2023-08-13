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

public final actor JFImageDownloader: JFImageDownloadable {
    public static let shared: JFImageDownloader = JFImageDownloader()
    
    private init() { }
    
    private enum DownloadEntry {
        case inProgress(Task<JFImageData, Error>)
        case ready(JFImageData)
    }
    
    private var cache: [URL: DownloadEntry] = [:]
    
    public func downloadImage(from url: URL, eTag: String? = nil) async throws -> JFImageData {
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
    
    public func download(url: URL, eTag: String? = nil) async throws -> JFImageData {
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
