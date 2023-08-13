//
//  String+JF.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/24.
//

import Foundation

extension String {
    /// URL에서 확장자를 얻는 메서드
    /// - Returns: URL의 확장자
    func getJFImageFormatFromURLString() -> JFImageFormat {
        guard let fileName: String = self.components(separatedBy: "/").last,
              let imageFormatString = fileName.components(separatedBy: ".").last else {
            return .jpeg()
        }
        
        return (imageFormatString == "png") ? .png : .jpeg()
    }
}
