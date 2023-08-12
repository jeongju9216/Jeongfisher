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
    public func downloadImage(url urlString: String, eTag: String? = nil, completionHandler: @escaping (Result<JFImageData, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completionHandler(.failure(JeongNetworkError.urlError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let eTag = eTag {
            request.addValue(eTag, forHTTPHeaderField: "If-None-Match")
        }

        let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else {
                self?.removeDictionaryValue(url: urlString)
                completionHandler(.failure(JeongNetworkError.imageDownloadError))
                return
            }
            
            if let error = error {
                self.removeDictionaryValue(url: urlString)
                completionHandler(.failure(error))
                return
            }
            
            guard let httpURLResponse = response as? HTTPURLResponse, (200..<400) ~= httpURLResponse.statusCode,
                  let data = data else {
                self.removeDictionaryValue(url: urlString)
                completionHandler(.failure(JeongNetworkError.imageDownloadError))
                return
            }
  
            let eTag: String = httpURLResponse.allHeaderFields["Etag"] as? String ?? ""
            let imageFormat: JFImageFormat = urlString.getJFImageFormatFromURLString()

            let imageData = JFImageData(data: data, eTag: eTag, imageExtension: imageFormat)
                            
            self.removeDictionaryValue(url: urlString)
            completionHandler(.success(imageData))
        }

        addRequestToDictionary(url: urlString, request: task)
    }
    
    //이미지 다운로드 취소
    public func cancelDownloadImage(url: String) {
        reqeusetSerialQueue.sync {
            if self.requestDir[url] != nil {
                self.requestDir[url]?.cancel()
                removeDictionaryValue(url: url)
            }
        }
    }
    
    private func addRequestToDictionary(url: String, request: URLSessionDataTask) {
        reqeusetSerialQueue.async(flags: .barrier, execute: {
            request.resume()
            self.requestDir[url] = request
        })
    }
    
    private func removeDictionaryValue(url: String) {
        reqeusetSerialQueue.async(flags: .barrier, execute: {
            self.requestDir[url] = nil
        })
    }
}
