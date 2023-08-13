//
//  JFImageDownloadable.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/14.
//

import UIKit

protocol JFImageDownloadable {
    func downloadImage(url: URL, eTag: String?) async throws -> JFImageData
    func cancelDownloadImage(url: String)
}
