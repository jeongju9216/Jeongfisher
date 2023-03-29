//
//  ImageDownloadable.swift
//  CloneStore
//
//  Created by jeongju.yu on 2023/02/14.
//

import UIKit

protocol JeongImageDownloadable {    
    func downloadImage(url urlString: String, eTag: String?) async throws -> JeongImageData
    func cancelDownloadImage(url: String)
}
