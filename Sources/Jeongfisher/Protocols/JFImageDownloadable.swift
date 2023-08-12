//
//  JFImageDownloadable.swift
//  Jeongfisher
//
//  Created by jeongju.yu on 2023/02/14.
//

import UIKit

protocol JFImageDownloadable {
    func downloadImage(url urlString: String, eTag: String?, completionHandler: @escaping (Result<JFImageData, Error>) -> Void)
    func cancelDownloadImage(url: String)
}
