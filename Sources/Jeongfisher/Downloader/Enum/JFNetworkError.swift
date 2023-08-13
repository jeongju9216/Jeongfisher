//
//  JFNetworkError.swift
//  Jeongfisher
//
//  Created by 유정주 on 2023/08/13.
//

import Foundation

public enum JFNetworkError: LocalizedError {
    case apiError
    case downloadImageError
    case urlError
}

extension JFNetworkError {
    public var errorDescription: String? {
        switch self {
        case .apiError: return "API 호출 에러"
        case .downloadImageError: return "이미지 다운로드 에러"
        case .urlError: return "잘못된 URL"
        }
    }
}
