//
//  JFOption.swift
//  Jeongfisher
//
//  Created by 유정주 on 2023/08/14.
//

import Foundation

/// Jeongfisher Option
public enum JFOption {
    /// 메모리 캐시만 사용. 디스크 캐시는 사용하지 않음
    case cacheMemoryOnly
    /// 데이터를 캐시에서만 얻음. 네트워크 사용하지 않음
    case onlyFromCache
    /// 캐시를 무시하고 네트워크 다운로드 진행
    case forceRefresh
    /// 다운샘플링을 진행하지 않음
    case showOriginalImage
    /// eTag를 사용함
    case disableETag
}

extension JFOption: Hashable { }
