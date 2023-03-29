//
//  String.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/24.
//

import Foundation

extension String {
    func getJeongImageFormatFromURLString() -> JeongImageFormat {
        guard let fileName: String = self.components(separatedBy: "/").last,
              let imageFormatString = fileName.components(separatedBy: ".").last else {
            return .jpeg()
        }
        
        return (imageFormatString == "png") ? .png : .jpeg()
    }
}
