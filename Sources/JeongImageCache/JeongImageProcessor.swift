//
//  JeongImageProcessor.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

//이미지 처리 담당 싱글톤 객체
//리사이징, 데이터 압축, 압축해제해서 캐셔에서 사용
public final class JeongImageProcessor: JeongImageProcessable {
    public static let shared: JeongImageProcessor = JeongImageProcessor()
    
    private init() { }
    
    //사이즈로 이미지 크기 조절
    public func resizedImage(_ image: UIImage, newSize: CGSize) -> UIImage? {
        guard image.size != newSize else {
            return image
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        //todo: 다양한 이미지 크기 조절 방법 비교(UIKit(UIGraphicsBeginBeginImageContext, UIGraphicsImageRenderer), Core Graphic, Core Image, vImage)
        //note: 고용량, 고품질 이미지 작업은 안 하니 과한 작업은 todo로 남겨두고 일정 관리
        let render = UIGraphicsImageRenderer(size: newSize)
        let renderImage = render.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        let endTime = CFAbsoluteTimeGetCurrent() - startTime
        JICLogger.log("[ImageProcessor] (\(Int(image.size.width)), \(Int(image.size.height))) -> (\(Int(newSize.width)), \(Int(newSize.height))) / Time: \(endTime)")
        
        return renderImage
    }
    
    //비율로 이미지 크기 조절
    public func resizedImage(_ image: UIImage, scale: CGFloat) -> UIImage? {
        let newSize: CGSize = CGSize(width: image.size.width * scale,
                                     height: image.size.height * scale)
        
        let render = UIGraphicsImageRenderer(size: newSize)
        let renderImage = render.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return renderImage
    }
}
