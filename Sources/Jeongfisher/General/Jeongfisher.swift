//
//  Jeongfisher.swift
//  Jeongfisher
//
//  Created by 유정주 on 2023/08/11.
//

import UIKit

public struct JeongfisherWrapper<Base> {
    
    public let base: Base
    
    public init(base: Base) {
        self.base = base
    }
}

/// Jeongfisher와 호환 여부
public protocol JeongfisherCompatible: AnyObject {}

extension JeongfisherCompatible {
    /// Wrapping Value
    public var jf: JeongfisherWrapper<Self> {
        return JeongfisherWrapper(base: self)
    }
}

extension UIImageView: JeongfisherCompatible {}
