//
//  JFCacheError.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/21.
//

import Foundation

///캐시에서 발생하는 에러
enum JFCacheError: Error {
    case saveError
    case fetchError
    case deleteError
}
