//
//  JeongImageCache.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit
import Combine

public struct JeongImageData: Codable {
    public var data: Data //이미지 데이터
    public var eTag: String
    public var imageExtension: JeongImageFormat //png, jpeg (UIImage <-> Data 변환, 압축에 사용)
}

/*
 note
 - 메모리 전환 정책 : LRU => 최근에 로드한 이미지를 메모리에 남겨둠
 - 앱 시작 시 디스크 캐시에서 메모리 캐시로 올릴 기준
 - 상세 정보 기록만 로드함
 - 키 값은 URL String 그대로 사용
 - 파일 이름이 중복되지 않는다는 확신이 없음
 - URL의 앞부분이 공통된다면 삭제 후 키 값으로 이용하려 했으나,
 - https:// 직후도 다를 수 있는 케이스를 발견하여 URL String 그대로 사용하는 것으로 결정
 */
/// 이미지를 캐시하는 싱글톤 클래스.
/// 메모리 캐시, 디스크 캐시를 이용해 캐시 진행
public class JeongImageCache {
    public static let shared: JeongImageCache = JeongImageCache()
    
    private init() {
        Task {
            startCleanCacheTimer()
        }
    }
    
    public enum CacheType {
        case memory, disk
    }
    
    public typealias ImageCacheItem = JeongCacheItem<JeongImageData>
    
    //메모리 캐시 : 딕셔너리, 양방향 링크드 리스트를 이용한 메모리 캐시
    private var memoryCache: JeongMemoryCache<ImageCacheItem> = JeongMemoryCache(capacity: .MB(1),
                                                                       cacheDataSizeLimit: .KB(100),
                                                                       cachePolicy: .LRU)
    //메모리 캐시 만료 시간
    private(set) var memoryCacheItemExpiredTime: JeongCacheExpiration = .minutes(10)
    //메모리 캐시 만료 시간 측정 기준
    private(set) var memoryCacheItemStandardExpiration: StandardJeongCacheExpiration = .lastHit
    //만료된 메모리 캐시 정리 주기
    private(set) var cleanMemoryCacheExpiredTime: JeongCacheExpiration = .minutes(5)
    
    //디스크 캐시 : FileManager를 이용한 디스크 캐시
    private var diskCache: JeongDiskCache<ImageCacheItem> = JeongDiskCache(capacity: .MB(100),
                                                                 cacheDataSizeLimit: .MB(10),
                                                                 cacheFolderName: "CloneStore")
    //디스크 캐시 만료 시간
    private(set) var diskCacheItemExpiredTime: JeongCacheExpiration = .days(7)
    //디스크 캐시 만료 시간 측정 기준
    private(set) var diskCacheItemStandardExpiration: StandardJeongCacheExpiration = .create
    //만료된 디스크 캐시 정리 주기
    private(set) var cleanDiskCacheExpiredTime: JeongCacheExpiration = .days(7)
    
    private var cleanMemoryCacheCancellable: Cancellable?
    
    ///캐시를 이용해 이미지 반환
    ///- Parameters:
    ///     - url: 이미지 URL
    ///     - usingETag: ETag 사용 여부
    ///- Returns: 캐시 혹은 네트워크를 통해 생성한 JeongImageData
    public func getImageWithCache(url: String, usingETag: Bool = true) async -> JeongImageData? {
        //메모리 캐시: 만료되었더라도 아직 정리되지 않았다면 다시 살림
        if let memoryCacheData = memoryCache.getData(key: url) {
            JICLogger.log("[ImageCache] Get Memory Cache")
            return memoryCacheData.data
        }
        
        //디스크 캐시: 만료된 데이터는 사용하지 않음
        if var diskCacheData = diskCache.getData(key: url) {
            if usingETag {
                let diskDataETag: String = diskCacheData.data.eTag
                //eTag 확인
                if let networkImageData = await getImageFromNetwork(url: url, eTag: diskDataETag) {
                    let serverEtag = networkImageData.eTag
                    if !serverEtag.isEmpty && serverEtag != diskDataETag {
                        //다르면 디스크 캐시에 새로운 데이터 저장
                        JICLogger.log("[ImageCache] Get Disk Cache - Update New Data")
                        
                        diskCacheData.data = networkImageData
                        saveDiskCache(key: url, data: diskCacheData.data)
                    } else {
                        JICLogger.log("[ImageCache] Get Disk Cache - Same Data")
                    }
                }
            }
            
            saveMemoryCache(key: url, data: diskCacheData.data)
            return diskCacheData.data
        }
        
        JICLogger.log("[ImageCache] Get Network")
        if let imageData = await getImageFromNetwork(url: url) {
            saveImageData(url: url, imageData: imageData)
            return imageData
        } else {
            return nil
        }
    }
    
    ///네트워크를 이용해 이미지 반환
    ///- Parameters:
    ///     - url: 이미지 URL
    ///- Returns: 네트워크를 통해 생성한 JeongImageData
    public func getImageFromNetwork(url: String, eTag: String? = nil) async -> JeongImageData? {
        do {
            //네트워크
            let startTime = CFAbsoluteTimeGetCurrent()
            let imageData: JeongImageData = try await JeongImageDownloader.shared.downloadImage(url: url, eTag: eTag)
            let endTime = CFAbsoluteTimeGetCurrent() - startTime
            JICLogger.log("[Time] request downloadImage: \(endTime)")
            
            return imageData
        } catch {
            JICLogger.error("Get Network Cache Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    ///캐시에 이미지 데이터 저장
    ///- Parameters:
    ///     - url: Key로 사용될 이미지 URL
    ///     - imageData
    ///- Returns: 캐시 혹은 네트워크를 통해 생성한 JeongImageData
    public func saveImageData(url: String, imageData: JeongImageData) {
        saveMemoryCache(key: url, data: imageData)
        saveDiskCache(key: url, data: imageData)
    }
    
    ///JeongImageCache의 메모리 캐시 설정
    ///- Parameters:
    ///     - new: JeongImageCache에서 사용할 JeongMemoryCache 객체
    public func changeMemoryCache(_ new: JeongMemoryCache<ImageCacheItem>) {
        self.memoryCache = new
    }
    
    ///JeongImageCache의 디스크 캐시 설정
    ///- Parameters:
    ///     - new: JeongImageCache에서 사용할 JeongDiskCache 객체
    public func changeDiskCache(_ new: JeongDiskCache<ImageCacheItem>) {
        self.diskCache = new
    }
    
    ///캐시 아이템의 만료 시간 설정
    ///- Parameters:
    ///     - cacheExpiredTime: 만료 시간
    ///     - cacheType: memory or disk
    public func updateCacheItemExpiredTime(_ cacheExpiredTime: JeongCacheExpiration,
                                           cacheType: CacheType) {
        switch cacheType {
        case .memory:
            self.memoryCacheItemExpiredTime = cacheExpiredTime
        case .disk:
            self.diskCacheItemExpiredTime = cacheExpiredTime
        }
    }
    
    ///캐시 아이템의 만료 시간 측정 기준 설정
    ///- Parameters:
    ///     - standardExpiration: 만료 시간 측정 기준
    ///     - cacheType: memory or disk
    public func updateCacheItemStandardExpiration(_ standardExpiration: StandardJeongCacheExpiration,
                                                  cacheType: CacheType) {
        switch cacheType {
        case .memory:
            self.memoryCacheItemStandardExpiration = standardExpiration
        case .disk:
            self.diskCacheItemStandardExpiration = standardExpiration
        }
    }
    
    ///JeongImageCache의 주기적인 캐시 정리 시간 설정
    ///- Parameters:
    ///     - cleanCacheTime: 캐시 정리 시간
    ///     - cacheType: memory or disk
    public func updateCleanCacheTime(cleanCacheTime: JeongCacheExpiration,
                                     cacheType: CacheType) {
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
extension JeongImageCache {
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
                
                JICLogger.log("[ImageCache] Clean Memory Cache Data")
                
                self.cleanExpiredMemoryCacheData()
            }
    }
    
    private func startCleanDiskCacheTimer() {
        cleanExpiredDiskCacheData()
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
extension JeongImageCache {
    private func saveMemoryCache(key: String, data: JeongImageData) {
        let dataSize: JeongDataSize = .Byte(data.data.count)
        if memoryCache.isLessSizeThanDataSizeLimit(size: dataSize) {
            let cacheItem: ImageCacheItem = ImageCacheItem(expiration: memoryCacheItemExpiredTime,
                                                           standardExpiration: memoryCacheItemStandardExpiration,
                                                           data: data,
                                                           size: dataSize)
            do {
                try self.memoryCache.saveCache(key: key, data: cacheItem)
            } catch {
                JICLogger.error("Save Memory Cache Error")
            }
        } else {
            JICLogger.log("[Memory Cache] Data is Bigger than data size limit")
        }
    }
    
    private func cleanExpiredMemoryCacheData() {
        DispatchQueue.global().async { [weak self] in
            self?.memoryCache.cleanExpiredData()
        }
    }
}

//MARK: - Disk Cache
extension JeongImageCache {
    private func saveDiskCache(key: String, data: JeongImageData) {
        let dataSize: JeongDataSize = .Byte(data.data.count)
        if diskCache.isLessSizeThanDataSizeLimit(size: dataSize) {
            let cacheItem: ImageCacheItem = ImageCacheItem(expiration: diskCacheItemExpiredTime,
                                                           standardExpiration: diskCacheItemStandardExpiration,
                                                           data: data,
                                                           size: dataSize)
            do {
                try self.diskCache.saveCache(key: key, data: cacheItem)
            } catch {
                JICLogger.error("Save Disk Cache Error")
            }
        } else {
            JICLogger.log("[Disk Cache] Data is Bigger than data size limit")
        }
    }
    
    private func cleanExpiredDiskCacheData() {
        DispatchQueue.global().async { [weak self] in
            do {
                try self?.diskCache.cleanExpiredData()
            } catch {
                JICLogger.error(error.localizedDescription)
            }
        }
    }
}
