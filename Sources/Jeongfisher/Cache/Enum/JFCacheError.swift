//
//  JFCacheError.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/21.
//

import Foundation

/// Cache에서 발생하는 에러
public enum JFCacheError: LocalizedError {
    case saveError
    case fetchError
    case deleteError
}

extension JFCacheError {
    public var errorDescription: String? {
        switch self {
        case .saveError: return "캐시 save 에러"
        case .fetchError: return "캐시 fetch 에러"
        case .deleteError: return "캐시 delete 에러"
        }
    }
}
