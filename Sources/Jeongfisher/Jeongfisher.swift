//
//  Jeongfisher.swift
//  Jeongfisher
//
//  Created by 유정주 on 2023/08/11.
//

import UIKit

public struct JeongfisherWrapper<Base> {
    
    // MARK: - Properties
    public let base: Base
    
    // MARK: - Methods
    public init(base: Base) {
        self.base = base
    }
}

public protocol JeongfisherCompatible: AnyObject {}

extension JeongfisherCompatible {
    public var jf: JeongfisherWrapper<Self> {
        return JeongfisherWrapper(base: self)
    }
}

// MARK: - Conforms Queenfisher Compatible
extension UIImage: JeongfisherCompatible {}
extension UIImageView: JeongfisherCompatible {}
