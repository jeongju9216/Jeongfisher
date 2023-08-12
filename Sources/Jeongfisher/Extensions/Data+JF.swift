//
//  Data+JF.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

extension Data {
    public func convertToImage() -> UIImage? {
        return UIImage(data: self)
    }
    
    public func downsampling(to targetSize: CGSize, scale: CGFloat = 1) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, imageSourceOptions) else { return nil }
        
        let maxDimension = Swift.max(targetSize.width, targetSize.height) * scale
        let downsamplingOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsamplingOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}
