//
//  ImageProcessable.swift
//  CloneStore
//
//  Created by jeongju.yu on 2023/02/15.
//

import UIKit

//이미지 처리 관련 동작 프로토콜
protocol JeongImageProcessable {
    func resizedImage(_ image: UIImage, newSize: CGSize) -> UIImage? //이미지 크기 조절
}
