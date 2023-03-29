//
//  JICLogger.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/03.
//

import Foundation
import OSLog

final class JICLogger {
    static func log<T>(_ object: T?, level: OSLogType = .default, fileName: String = #fileID, line: Int = #line, funcName: String = #function) {
        var message = ""
        if let object = object {
            message = "[JIC] \(String(describing: object))"
        } else {
            message = "[JIC]: object is nil)"
        }
        
        os_log(level, "%@", message)
    }
    
    static func error<T>(_ object: T?, level: OSLogType = .error, fileName: String = #fileID, line: Int = #line, funcName: String = #function) {
        var message = ""
        if let object = object {
            message = "[JIC] \(String(describing: object))"
        } else {
            message = "[JIC]: object is nil)"
        }
        
        os_log(level, "%@", message)
    }
}
