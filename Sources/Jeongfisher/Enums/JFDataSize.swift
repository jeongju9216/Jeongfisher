//
//  JFDataSize.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/16.
//

import Foundation

/// 캐시 데이터 크기
public enum JFDataSize: Codable {
    case Byte(Int)
    case KB(Int)
    case MB(Int)
    case GB(Int)
    case Infinity
    
    public var byte: Int64 {
        switch self {
        case .Byte(let size):
            return Int64(size)
        case .KB(let size):
            return Int64(size * 1024)
        case .MB(let size):
            return Int64(size * Int(pow(1024, 2.0)))
        case .GB(let size):
            return Int64(size * Int(pow(1024, 3.0)))
        case .Infinity:
            return Int64.max
        }
    }
    
    public var killoByte: Double {
        switch self {
        case .Byte(let size):
            return Double(size) / 1024.0
        case .KB(let size):
            return Double(size)
        case .MB(let size):
            return Double(size) * 1024.0
        case .GB(let size):
            return Double(size) * pow(1024, 2.0)
        case .Infinity:
            return Double.infinity
        }
    }
    
    public var megaByte: Double {
        switch self {
        case .Byte(let size):
            return Double(size) / pow(1024, 2.0)
        case .KB(let size):
            return Double(size) / 1024.0
        case .MB(let size):
            return Double(size)
        case .GB(let size):
            return Double(size) * 1024.0
        case .Infinity:
            return Double.infinity
        }
    }
    
    public var gigaByte: Double {
        switch self {
        case .Byte(let size):
            return Double(size) / pow(1024, 3.0)
        case .KB(let size):
            return Double(size) / pow(1024, 2.0)
        case .MB(let size):
            return Double(size) / 1024.0
        case .GB(let size):
            return Double(size)
        case .Infinity:
            return Double.infinity
        }
    }
}
