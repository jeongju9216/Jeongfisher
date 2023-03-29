//
//  Cacheable.swift
//  CloneStore
//
//  Created by jeongju.yu on 2023/02/15.
//

import Foundation

//캐싱 동작 프로토콜
public protocol JeongCacheable {
    associatedtype Key: Hashable//캐시 키
    associatedtype Value: JeongCacheItemable //캐싱할 데이터 타입
    
    func saveCache(key: Key, data: Value, overwrite: Bool) throws //캐시에 저장
    func getData(key: Key) -> Value?
}

//캐시되는 아이템이 가져야할 프로퍼티
public protocol JeongCacheItemable: Codable {
    associatedtype T
    
    var priority: Int { get } //우선순위(직접 할당할 때만 Int값, 기본 0)
    var size: JeongDataSize { get } //데이터 사이즈
    var firstCachedTimeInterval: TimeInterval { get } //처음 캐싱된 날짜(이후 추가 갱신하지 않아도 되서 gettable)
    var hitCount: Int { get set } //Hit 횟수
    var lastHitTimeInterval: TimeInterval { get set } //마지막 hit 날짜(만료시간 계산 용이성을 위해 TimeInterval 타입 채택)
    var expiration: JeongCacheExpiration { get } //만료 시간
    var isExpired: Bool { get }
    var data: T { get set }
}
