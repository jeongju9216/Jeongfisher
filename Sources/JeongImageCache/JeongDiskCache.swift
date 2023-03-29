//
//  JeongDiskCache.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

//디스크 캐싱을 담당하는 클래스
/*
 note
 - 디스크 캐시는 "생성" 날짜로만 만료 판단
 - 생성 날짜가 만료 기준을 넘으면 삭제 -> cleanExpiredTime에 삭제
 - 디스크 캐시의 장점인 큰 용량을 살리기 위해 최대한 저장해둘 예정
 - 데이터는 이미지 data, createdAt TimeInterval 1970 구조체 저장
    - 인코딩해서 저장하고, 디코딩해서 불러오고
 */

open class JeongDiskCache<Item: JeongCacheItemable>: JeongCacheable {
    public typealias Key = String
    public typealias Value = Item
    
    private let folderName: String
    
    private(set) var currentCachedCost: Int64 = 0
    private(set) var capacity: JeongDataSize
    private(set) var cacheDataSizeLimit: JeongDataSize
    
    private let fileManager = FileManager.default
    
    public init(capacity: JeongDataSize = .MB(100),
         cacheDataSizeLimit: JeongDataSize = .Infinity,
         cacheFolderName: String = "CloneStore") {
        self.capacity = capacity
        self.cacheDataSizeLimit = cacheDataSizeLimit
        self.folderName = cacheFolderName
        
        createDirectory()
    }
    
    internal func isLessSizeThanDataSizeLimit(size: JeongDataSize) -> Bool {
        return cacheDataSizeLimit.byte >= size.byte
    }
    
    //캐시 데이터 저장
    public func saveCache(key: String, data: Item, overwrite: Bool = false) throws {
        JICLogger.log("[Disk Cache] Capacity: \(capacity.byte) / current: \(currentCachedCost) / data size: \(data.size.byte)")

        let key = key.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: ".", with: "")
        let newKey: String = folderName + "/" + key
        
        guard let fileURL = getCacheFileURL(fileName: newKey) else {
            JICLogger.error("[Disk Cache] fileURL is nil")
            //todo: throw error
            throw JeongCacheError.saveError
        }
        
        if fileManager.fileExists(atPath: newKey) && !overwrite {
            JICLogger.log("[Disk Cache] \(newKey) is Already Exists.")
            throw JeongCacheError.saveError
        }

        if let contents = encode(item: data) {
            let saveResult: Bool = fileManager.createFile(atPath: fileURL.path, contents: contents)
            JICLogger.log("[Disk Cache] Save(\(saveResult)): \(newKey)")
            if !saveResult {
                throw JeongCacheError.saveError
            }
        } else {
            JICLogger.error("[Disk Cache] contents is nil")
            throw JeongCacheError.saveError
        }
    }
    
    public func getData(key: String) -> Item? {
        let key = key.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: ".", with: "")
        let newKey: String = folderName + "/" + key
        
        guard let fileURL = getCacheFileURL(fileName: newKey) else {
            return nil
        }
        
        if fileManager.fileExists(atPath: fileURL.path) {
            guard let fileData = try? Data(contentsOf: fileURL) else {
                //todo: throw fileURL 에러
                return nil
            }
            
            guard let cacheItem = decode(data: fileData) else {
                //todo: throw decode 에러
                return nil
            }
            
            JICLogger.log("[Disk Cache] Get: \(newKey)")
            return cacheItem
        } else {
            return nil
        }
    }
    
    //캐시 데이터 삭제
    @discardableResult
    public func deleteCache(url: URL) throws -> Item? {
        JICLogger.log("[Disk Cache] Delete: \(url)")
        do {
            let item: Item? = getData(key: url.absoluteString)
            try fileManager.removeItem(at: url)
            return item
        } catch {
            //todo: remove 에러
            throw JeongCacheError.deleteError
        }
    }
    
    @discardableResult
    public func deleteAllCache() throws -> Int {
        var deleteCount: Int = 0
        guard let folderURL = getCacheFileURL(fileName: folderName) else {
            throw JeongCacheError.deleteError
        }
    
        do {
            let fileNames: [String] = try fileManager.contentsOfDirectory(atPath: folderURL.path)
            
            for fileName in fileNames {
                guard let fileURL = getCacheFileURL(fileName: folderName + "/" + fileName) else {
                    continue
                }
                
                if let _ = try? deleteCache(url: fileURL) {
                    deleteCount += 1
                }
            }
            
            return deleteCount
        } catch {
            throw JeongCacheError.deleteError
        }
    }
    
    //만료된 캐시 삭제
    @discardableResult
    public func cleanExpiredData() throws -> Int {
        var deleteCount: Int = 0
        JICLogger.log("[Disk Cache] Clean Expired Data")
        
        guard let folderURL = getCacheFileURL(fileName: folderName) else {
            throw JeongCacheError.fetchError
        }
    
        do {
            let fileNames: [String] = try fileManager.contentsOfDirectory(atPath: folderURL.path)
            
            for fileName in fileNames {
                guard let fileURL = getCacheFileURL(fileName: folderName + "/" + fileName),
                      let cacheItem = getData(key: fileName) else {
                    continue
                }
                
                if cacheItem.isExpired, let _ = try deleteCache(url: fileURL) {
                    deleteCount += 1
                }
            }
            
            return deleteCount
        } catch {
            throw JeongCacheError.fetchError
        }
    }
    
    private func createDirectory() {
        guard let folderURL = getCacheFileURL(fileName: folderName) else {
            return
        }
        
        do {
            //withIntermediateDirectories true => 상위 폴더까지 모두 생성
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            JICLogger.error(error.localizedDescription)
        }
    }
    
    private func getCacheFileURL(fileName: String) -> URL? {
        guard let cacheDirPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = cacheDirPath.appendingPathComponent(fileName)

        return fileURL
    }
    
    private func encode(item: Item) -> Data? {
        return try? JSONEncoder().encode(item)
    }
    
    private func decode(data: Data) -> Value? {
        return try? JSONDecoder().decode(Item.self, from: data)
    }
}
