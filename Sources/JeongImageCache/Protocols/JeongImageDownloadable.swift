//
//  ImageDownloadable.swift
//  CloneStore
//
//  Created by jeongju.yu on 2023/02/14.
//

import UIKit

protocol JeongImageDownloadable {
    func downloadImage(url urlString: String, eTag: String?, completionHandler: @escaping (Result<JeongImageData, Error>) -> Void)
    func cancelDownloadImage(url: String)
}
