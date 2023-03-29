//
//  JeongCacheItem.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/15.
//

import Foundation

/// Jeong Cache에서 사용되는 CacheItem
public struct JeongCacheItem<T: Codable>: JeongCacheItemable {
    public var priority: Int //우선순위(직접 설정할 때만 설정)
    ///캐시 아이템 사이즈
    public var size: JeongDataSize //원본 이미지 사이즈(화면에 표시되는 사이즈 X)
    ///처음 캐싱된 Date
    public var firstCachedTimeInterval: TimeInterval
    public var firstCachedDate: Date {
        return Date(timeIntervalSince1970: firstCachedTimeInterval)
    }
    ///캐시 아이템이 hit 된 count
    public var hitCount: Int
    ///마지막으로 Hit된 Date
    public var lastHitTimeInterval: TimeInterval
    public var lastHitDate: Date {
        return Date(timeIntervalSince1970: lastHitTimeInterval)
    }
    ///캐시 아이템의 만료 시간
    public var expiration: JeongCacheExpiration
    ///캐시 아이템의 만료 시간 측정 기준
    public var standardExpiration: StandardJeongCacheExpiration
    public var expiredTimeInterval: TimeInterval {
        switch self.standardExpiration {
        case .create:
            return firstCachedTimeInterval + expiration.timeInterval
        case .lastHit:
            return lastHitTimeInterval + expiration.timeInterval
        }
    }
    public var expiredDate: Date {
        return Date(timeIntervalSince1970: expiredTimeInterval)
    }
    ///캐시 아이템 만료 여부
    public var isExpired: Bool {
        return expiredTimeInterval - Date().timeIntervalSince1970 < 0
    }
    ///캐시 아이템의 데이터
    public var data: T
    
    /// - Parameters:
    ///     - priority: 캐시 아이템의 우선순위
    ///     - expiration: 캐시 아이템 만료 시간
    ///     - standardExpiration: 캐시 아이템 만료 시간 측정 기준
    ///     - data: 캐시 데이터
    ///     - size: 캐시 데이터 사이즈
    public init(priority: Int = 0,
         expiration: JeongCacheExpiration = .minutes(5),
         standardExpiration: StandardJeongCacheExpiration = .lastHit,
         data: T,
         size: JeongDataSize) {
        self.priority = priority
        self.expiration = expiration
        self.standardExpiration = standardExpiration
        
        self.data = data
        self.size = size
        
        self.firstCachedTimeInterval = Date().timeIntervalSince1970
        self.lastHitTimeInterval = firstCachedTimeInterval
        self.hitCount = 0
    }
}
