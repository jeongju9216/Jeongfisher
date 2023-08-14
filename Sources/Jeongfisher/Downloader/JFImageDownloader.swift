//
//  JFImageDownloader.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/14.
//

import UIKit

/// URL을 이용한 이미지 다운로드
public final actor JFImageDownloader: JFImageDownloadable {
    public static let shared = JFImageDownloader()
    
    private init() { }
    
    /// Task 상태
    private enum DownloadEntry {
        case inProgress(Task<JFImageData, Error>)
        case complete(JFImageData)
    }
    
    private var cache: [URL: DownloadEntry] = [:]
    private var count: [URL: Int] = [:]
    
    /// URL 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - eTag: 이미지 eTag
    /// - Returns: 이미지 다운로드 결과
    public func downloadImage(from url: URL, useETag: Bool = false) async throws -> JFImageData {
        count[url, default: 0] += 1
        defer {
            if count[url] != nil {
                count[url]! -= 1
                if count[url]! <= 0 {
                    cache[url] = nil
                    count[url] = nil
                }
            }
        }
        
        //이미 같은 URL 요청이 들어온 경우 Task 완료 대기
        if let cached = cache[url] {
            switch cached {
            case .inProgress(let task):
                return try await task.value
            case .complete(let jfImageData):
                return jfImageData
            }
        }
        
        let task = Task {
            try await download(from: url, useETag: useETag)
        }
        
        cache[url] = .inProgress(task)
        
        do {
            let jfImageData = try await task.value
            cache[url] = .complete(jfImageData)
            return jfImageData
        } catch {
            cache[url] = nil
            throw error
        }
    }
    
    public func fetchImage(from url: URL, useETag: Bool = false) async -> UIImage? {
        return try? await downloadImage(from: url, useETag: useETag).data.convertToImage()
    }
    
    /// URL 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - eTag: 이미지 eTag
    /// - Returns: 이미지 다운로드 결과
    private func download(from url: URL, useETag: Bool = false) async throws -> JFImageData {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpURLResponse = response as? HTTPURLResponse, (200..<400) ~= httpURLResponse.statusCode else {
            throw JFNetworkError.downloadImageError
        }
        
        let eTag = useETag ? httpURLResponse.allHeaderFields["Etag"] as? String
                           : nil
        let imageFormat: JFImageFormat = url.absoluteString.getJFImageFormatFromURLString()
        
        let imageData = JFImageData(data: data, eTag: eTag, imageExtension: imageFormat)
        
        return imageData
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
