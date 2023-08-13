//
//  UIImage+JF.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

public enum JFImageFormat: Codable {
    case png
    case jpeg(compressionQuality: CGFloat = 1.0)
}

extension UIImage {
    /// UIImage를 Data로 변환
    /// - Parameter format: 이미지 format
    /// - Returns: UIImage를 변환한 data
    public func convertToData(format: JFImageFormat) -> Data? {
        switch format {
        case .png:
            return self.pngData()
        case .jpeg(let compressionQuality):
            return self.jpegData(compressionQuality: compressionQuality)
        }
    }
}
