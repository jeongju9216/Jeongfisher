//
//  Data.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

extension Data {
    public func convertToImage() -> UIImage? {
        return UIImage(data: self)
    }
}
