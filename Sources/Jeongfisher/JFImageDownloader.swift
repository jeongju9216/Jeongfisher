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

//이미지 다운로드 클래스
//킹피셔대타에서 캐시에 없을 때 ImageDownloader 이용해서 네트워크로 이미지 요청
public final class JFImageDownloader: JFImageDownloadable {
    public static let shared: JFImageDownloader = JFImageDownloader()
    
    private init() { }
    
    //request들 보관하는 디렉토리(키: URL string)
    private var requestDir: [String: URLSessionDataTask] = [:]
    
    //get: sync => 순차적 진행해야 Write랑 안 겹쳐서 정확한 값 얻어옴
    //set: async + barrier => 다음 코드를 진행 && 데이터 레이스 방지
    private var reqeusetSerialQueue = DispatchQueue(label: "com.jeongfisher.reqeusetQueue", attributes: .concurrent)
    
    //이미지 다운로드
    public func downloadImage(url: URL, eTag: String? = nil) async throws -> JFImageData {
        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            if let eTag = eTag {
                request.addValue(eTag, forHTTPHeaderField: "If-None-Match")
            }
            
            let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
                guard let self = self else {
                    self?.removeDictionaryValue(key: url.absoluteString)
                    continuation.resume(with: .failure(JeongNetworkError.apiError))
                    return
                }
                
                if let error = error {
                    self.removeDictionaryValue(key: url.absoluteString)
                    continuation.resume(with: .failure(error))
                    return
                }
                
                guard let httpURLResponse = response as? HTTPURLResponse, (200..<400) ~= httpURLResponse.statusCode,
                      let data = data else {
                    self.removeDictionaryValue(key: url.absoluteString)
                    continuation.resume(with: .failure(JeongNetworkError.imageDownloadError))
                    return
                }
                
                JICLogger.log("[JIC] statusCode: \(httpURLResponse.statusCode) / data: \(data.count)")
                
                let eTag: String = httpURLResponse.allHeaderFields["Etag"] as? String ?? ""
                //                let eTag: String = "Update Test Etag"
                let imageFormat: JFImageFormat = url.absoluteString.getJFImageFormatFromURLString()
                
                let imageData = JFImageData(data: data, eTag: eTag, imageExtension: imageFormat)
                
                self.removeDictionaryValue(key: url.absoluteString)
                continuation.resume(with: .success(imageData))
            }
            
            addRequestToDictionary(key: url.absoluteString, request: task)
        }
    }
    
    //이미지 다운로드 취소
    public func cancelDownloadImage(url: String) {
        reqeusetSerialQueue.sync {
            if self.requestDir[url] != nil {
                self.requestDir[url]?.cancel()
                removeDictionaryValue(key: url)
            }
        }
    }

    private func addRequestToDictionary(key: String, request: URLSessionDataTask) {
        reqeusetSerialQueue.async(flags: .barrier, execute: {
            if self.requestDir[key] == nil {
                request.resume()
                self.requestDir[key] = request
            }
        })
    }

    private func removeDictionaryValue(key: String) {
        reqeusetSerialQueue.async(flags: .barrier, execute: {
            self.requestDir[key] = nil
        })
    }
}
