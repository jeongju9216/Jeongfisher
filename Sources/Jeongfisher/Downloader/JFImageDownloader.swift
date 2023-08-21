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
    ///   - etag: 이미지 ETag
    /// - Returns: 이미지 다운로드 결과
    public func downloadImage(from url: URL, etag: String? = nil) async throws -> JFImageData {
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
            try await download(from: url, etag: etag)
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
    
    public func fetchImage(from url: URL, etag: String? = nil) async -> UIImage? {
        return try? await downloadImage(from: url, etag: etag).data.convertToImage()
    }
    
    /// URL 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - etag: 이미지 ETag
    /// - Returns: 이미지 다운로드 결과
    private func download(from url: URL, etag: String? = nil) async throws -> JFImageData {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let etag = etag {
            request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpURLResponse = response as? HTTPURLResponse,
                (200..<400) ~= httpURLResponse.statusCode else {
            throw JFNetworkError.downloadImageError
        }
        
        let newETag = httpURLResponse.value(forHTTPHeaderField: "Etag")
        if etag != nil && newETag == etag {
            throw JFNetworkError.notChangedETag
        }
        
        switch httpURLResponse.statusCode {
        case 200..<299:
            let imageFormat = url.absoluteString.getJFImageFormatFromURLString()
            return JFImageData(data: data, ETag: newETag, imageExtension: imageFormat)
        case 304:
            throw JFNetworkError.notChangedETag
        default:
            throw JFNetworkError.downloadImageError
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
