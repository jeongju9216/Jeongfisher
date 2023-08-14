//
//  JeongImageCache.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit
import Combine

public struct JFImageData: Codable {
    public var data: Data //이미지 데이터
    public var ETag: String?
    public var imageExtension: JFImageFormat //png, jpeg (UIImage <-> Data 변환, 압축에 사용)
}

/// 이미지를 캐시하는 싱글톤 클래스.
/// 메모리 캐시, 디스크 캐시를 이용해 캐시 진행
public class JFImageCache {
    public typealias ImageCacheItem = JFCacheItem<JFImageData>

    public typealias MemoryCache = JFMemoryCache<ImageCacheItem>
    public typealias DiskCache = JFDiskCache<ImageCacheItem>
    
    public static let shared: JFImageCache = JFImageCache()
    
    private init() {
        Task { startCleanCacheTimer() }
    }
    
    /// JFImageCache에서 아용하는 캐시 타입
    public enum JFCacheType {
        case memory, disk
        
        static public func defaultCache<T>(_ cacheType: Self) -> T {
            switch cacheType {
            case .memory: return MemoryCache() as! T
            case .disk: return DiskCache() as! T
            }
        }
    }
    
    /// 딕셔너리, 양방향 링크드 리스트를 이용한 메모리 캐시
    private var memoryCache: MemoryCache = JFCacheType.defaultCache(.memory)
    /// 메모리 캐시 만료 시간
    private(set) var memoryCacheItemExpiredTime: JFCacheExpiration = .minutes(30)
    /// 메모리 캐시 만료 시간 측정 기준
    private(set) var memoryCacheItemStandardExpiration: StandardJFCacheExpiration = .lastHit
    /// 만료된 메모리 캐시 정리 주기
    private(set) var cleanMemoryCacheExpiredTime: JFCacheExpiration = .minutes(30)
    
    /// FileManager를 이용한 디스크 캐시
    private var diskCache: DiskCache = JFCacheType.defaultCache(.disk)
    /// 디스크 캐시 만료 시간
    private(set) var diskCacheItemExpiredTime: JFCacheExpiration = .days(7)
    /// 디스크 캐시 만료 시간 측정 기준
    private(set) var diskCacheItemStandardExpiration: StandardJFCacheExpiration = .create
    /// 만료된 디스크 캐시 정리 주기
    private(set) var cleanDiskCacheExpiredTime: JFCacheExpiration = .days(7)
    
    private var cleanMemoryCacheCancellable: Cancellable?
        
    /// 캐시를 이용해 이미지 반환
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - options: 사용할 JFOption
    /// - Returns: 캐시 혹은 네트워크를 통해 생성한 JeongImageData
    public func getImageWithCache(url: URL, options: Set<JFOption>) async -> JFImageData? {
        let key = url.absoluteString
        
        //메모리 캐시: 만료되었더라도 아직 정리되지 않았다면 다시 살림
        if let memoryCacheData = memoryCache.getData(key: key) {
            JFLogger.log("[ImageCache] Get Memory Cache")
            return memoryCacheData.data
        }
        
        //디스크 캐시: 만료된 데이터는 사용하지 않음
        if !options.contains(.cacheMemoryOnly) {
            if var diskCacheData = diskCache.getData(key: key) {
                if !options.contains(.disableETag), let diskDataETag = diskCacheData.data.ETag {
                    do {
                        //ETag 확인
                        if let newImageData = try await downloadImage(url: url, etag: diskDataETag) {
                            //다르면 디스크 캐시에 새로운 데이터 저장
                            JFLogger.log("[ImageCache] Get Disk Cache - Update New Data")

                            diskCacheData.data = newImageData
                            saveDiskCache(key: key, data: diskCacheData.data)
                        }
                    } catch JFNetworkError.notChangedETag {
                        JFLogger.log("[ImageCache] Get Disk Cache - Same Data")
                    } catch {
                    }
                }
                
                saveMemoryCache(key: key, data: diskCacheData.data)
                return diskCacheData.data
            }
        }
        
        guard !options.contains(.onlyFromCache) else { return nil }
        
        //네트워크 다운로드
        guard let imageData = try? await downloadImage(url: url) else {
            return nil
        }
        
        JFImageCache.shared.saveImageData(url: url.absoluteString, imageData: imageData)
        return imageData
    }
    
    ///네트워크를 이용해 이미지 반환
    ///- Parameters:
    ///   - url: 이미지 URL
    ///   - etag: URL ETag
    ///- Returns: 네트워크를 통해 생성한 JeongImageData
    public func downloadImage(url: URL, etag: String? = nil) async throws -> JFImageData? {
        return try await JFImageDownloader.shared.downloadImage(from: url, etag: etag)
    }
    
    ///캐시에 이미지 데이터 저장
    ///- Parameters:
    ///   - url: Key로 사용될 이미지 URL
    ///   - imageData: 저장할 JFImageData
    ///- Returns: 캐시 혹은 네트워크를 통해 생성한 JeongImageData
    public func saveImageData(url: String, imageData: JFImageData) {
        saveMemoryCache(key: url, data: imageData)
        saveDiskCache(key: url, data: imageData)
    }
    
    ///JeongImageCache의 메모리 캐시 설정
    ///- Parameters:
    ///   - new: JeongImageCache에서 사용할 JeongMemoryCache 객체
    public func changeMemoryCache(_ new: JFMemoryCache<ImageCacheItem>) {
        memoryCache = new
    }
    
    ///JeongImageCache의 디스크 캐시 설정
    ///- Parameters:
    ///   - new: JeongImageCache에서 사용할 JeongDiskCache 객체
    public func changeDiskCache(_ new: JFDiskCache<ImageCacheItem>) {
        diskCache = new
    }
    
    /// 캐시 아이템의 만료 시간 설정
    /// - Parameters:
    ///   - cacheExpiredTime: 만료 시간
    ///   - cacheType: 업데이트할 캐시 타입
    public func updateCacheItemExpiredTime(
        _ cacheExpiredTime: JFCacheExpiration,
        cacheType: JFCacheType)
    {
        switch cacheType {
        case .memory:
            self.memoryCacheItemExpiredTime = cacheExpiredTime
        case .disk:
            self.diskCacheItemExpiredTime = cacheExpiredTime
        }
    }
    
    /// 캐시 아이템의 만료 시간 측정 기준 설정
    /// - Parameters:
    ///   - standardExpiration: 만료 시간 측정 기준
    ///   - cacheType: 업데이트할 캐시 타입
    public func updateCacheItemStandardExpiration(
        _ standardExpiration: StandardJFCacheExpiration,
        cacheType: JFCacheType)
    {
        switch cacheType {
        case .memory:
            self.memoryCacheItemStandardExpiration = standardExpiration
        case .disk:
            self.diskCacheItemStandardExpiration = standardExpiration
        }
    }
    
    /// JeongImageCache의 주기적인 캐시 정리 시간 설정
    /// - Parameters:
    ///   - cleanCacheTime: 캐시 정리 시간
    ///   - cacheType: 업데이트할 캐시 타입
    public func updateCleanCacheTime(
        cleanCacheTime: JFCacheExpiration,
        cacheType: JFCacheType)
    {
        switch cacheType {
        case .memory:
            self.cleanMemoryCacheExpiredTime = cleanCacheTime
            startCleanMemoryCacheTimer()
        case .disk:
            self.cleanDiskCacheExpiredTime = cleanCacheTime
            startCleanDiskCacheTimer()
        }
    }
}

//MARK: - Clean Caches
extension JFImageCache {
    private func startCleanCacheTimer() {
        startCleanMemoryCacheTimer()
        startCleanDiskCacheTimer()
    }
    
    private func startCleanMemoryCacheTimer() {
        cleanMemoryCacheCancellable?.cancel()
        cleanMemoryCacheCancellable = Timer.publish(every: cleanMemoryCacheExpiredTime.timeInterval, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                JFLogger.log("[ImageCache] Clean Memory Cache Data")
                
                self.cleanExpiredMemoryCacheData()
            }
    }
    
    private func startCleanDiskCacheTimer() {
//        cleanExpiredDiskCacheData()
        //todo: fix: 마지막 디스크 청소 시간 기준으로 + cleanDiskCacheExpiredTime 변경해야 함
//        Timer.publish(every: cleanDiskCacheExpiredTime.timeInterval, on: .main, in: .default)
//            .autoconnect()
//            .sink { [weak self] _ in
//                guard let self = self else { return }
//
//                JICLogger.log("[ImageCache] Clean Disk Cache Data")
//
//                self.cleanExpiredDiskCacheData()
//            }.store(in: &cancellables)
    }
}

//MARK: - Memory Cache
extension JFImageCache {
    private func saveMemoryCache(key: String, data: JFImageData) {
        let dataSize: JFDataSize = .Byte(data.data.count)
        if memoryCache.isLessSizeThanDataSizeLimit(size: dataSize) {
            let cacheItem = ImageCacheItem(
                expiration: memoryCacheItemExpiredTime,
                standardExpiration: memoryCacheItemStandardExpiration,
                data: data,
                size: dataSize)
            
            try? self.memoryCache.saveCache(key: key, data: cacheItem)
        } else {
            JFLogger.log("[Memory Cache] Data is Bigger than data size limit")
        }
    }
    
    private func cleanExpiredMemoryCacheData() {
        self.memoryCache.cleanExpiredData()
    }
}

//MARK: - Disk Cache
extension JFImageCache {
    private func saveDiskCache(key: String, data: JFImageData) {
        let dataSize: JFDataSize = .Byte(data.data.count)
        if diskCache.isLessSizeThanDataSizeLimit(size: dataSize) {
            let cacheItem = ImageCacheItem(
                expiration: diskCacheItemExpiredTime,
                standardExpiration: diskCacheItemStandardExpiration,
                data: data,
                size: dataSize)
            
            do {
                try self.diskCache.saveCache(key: key, data: cacheItem)
            } catch {
                JFLogger.error(error.localizedDescription)
            }
        } else {
            JFLogger.log("[Disk Cache] Data is Bigger than data size limit")
        }
    }
    
    private func cleanExpiredDiskCacheData() {
        do {
            try self.diskCache.cleanExpiredData()
        } catch {
            JFLogger.error(error.localizedDescription)
        }
    }
}
