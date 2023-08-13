//
//  JFCacheExpiration.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/15.
//

import Foundation

/// 캐시 아이템의 만료 시간
/// - never : 만료 시키지 않음
/// - seconds : TimeInterval초 초과 시 만료
/// - minutes : Int분 초과 시 만료
/// - hourse : Int시 초과 시 만료
/// - days : Int일 초과 시 만료
/// - date : Date를 초과하면 만료
/// - expired : 만료됨
public enum JFCacheExpiration: Codable {
    case never //만료되지 않음
    case seconds(TimeInterval) //TimerInterval초/분/시 초과하면 만료됨
    case minutes(Int)
    case hours(Int)
    case days(Int) //Int일 초과하면 만료됨
    case date(Date) //Date를 지나면(초과) 만료됨
    case expired //만료됨
    
    public var timeInterval: TimeInterval {
        switch self {
        case .never:
            return .infinity
        case .seconds(let seconds):
            return seconds
        case .minutes(let minutes):
            return TimeInterval(minutes * 60)
        case .hours(let hours):
            return TimeInterval(hours * 60 * 60)
        case .days(let days):
            return TimeInterval(days * (24 * 60 * 60))
        case .date(let date):
            return date.timeIntervalSinceNow
        case .expired:
            return -(.infinity)
        }
    }
}

/// 캐시 아이템의 만료 시간 측정 기준
/// - create : 캐시 생성일 기준
/// - lastHit : 마지막 Hit 날짜 기준
public enum StandardJFCacheExpiration: Codable { //만료시간 기준
    case create, lastHit
}
