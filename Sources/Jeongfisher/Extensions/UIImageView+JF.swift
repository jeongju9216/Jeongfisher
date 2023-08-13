//
//  UIImageView+JF.swift
//  Jeongfisher
//
//  Created by 유정주 on 2023/08/11.
//

import UIKit
import Combine

extension JeongfisherWrapper where Base: UIImageView {
    
    
    
    ///url을 이용해 UIImage 설정
    ///
    ///- Parameters:
    ///     - url: 이미지 URL
    ///     - placeHolder: 이미지 다운로드 지연 시 보여줄 placeHolder
    ///     - watiPlaceHolderTime: placeHolde를 보여주기까지의 대기 시간
    ///     - useCache: 캐시 사용 여부 결정. false면 네트워크를 통해 이미지 다운로드
    public func setImage(with url: URL,
                          placeHolder: UIImage? = nil,
                          waitPlaceHolderTime: TimeInterval = 1,
                         useCache: Bool = true) {
        
        Task {
            var timer: Timer? = nil
            if let placeHolder = placeHolder {
                timer = Timer.scheduledTimer(withTimeInterval: waitPlaceHolderTime, repeats: true) { _ in
                    DispatchQueue.main.async {
                        self.base.image = placeHolder
                    }
                }
                timer?.fire()
            }
            
            let updatedImageData: JFImageData?
            if useCache,
                let cachedjfImageData = JFImageCache.shared.getImageWithCache(url: url.absoluteString) {
                updatedImageData = cachedjfImageData
            } else {
                let jfImageData = await getImageFromNetwork(url: url)
                updatedImageData = jfImageData
            }
            
            timer?.invalidate()
            
            if let downsampledImage = await updatedImageData?.data.downsampling(to: self.base.frame.size) {
                updateImage(downsampledImage)
            } else {
                updateImage(updatedImageData?.data.convertToImage())
            }
        }
    }
    
    private func updateImage(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.base.image = image
        }
    }
    
    ///네트워크를 이용해 이미지 반환
    ///- Parameters:
    ///     - url: 이미지 URL
    ///- Returns: 네트워크를 통해 생성한 JeongImageData
    public func getImageFromNetwork(url: URL, eTag: String? = nil) async -> JFImageData? {
        do {
            //네트워크
            let imageData: JFImageData = try await JFImageDownloader.shared.downloadImage(url: url, eTag: eTag)
            JFImageCache.shared.saveImageData(url: url.absoluteString, imageData: imageData)
            
            return imageData
        } catch {
            return nil
        }
    }
    
    ///진행 중인 URL 다운로드 취소
    ///
    ///- Parameters:
    ///     - url: 이미지 URL
    public func cancelDownloadImage(url: String) {
//        JFImageDownloader.shared.cancelDownloadImage(url: url)
    }
    
    private func showPlaceHolder(image: UIImage) -> UIImageView {
        let placeHolderImageView = UIImageView(image: image)
        placeHolderImageView.contentMode = .scaleAspectFit
        
        self.base.addSubview(placeHolderImageView)
        placeHolderImageView.translatesAutoresizingMaskIntoConstraints = false

        placeHolderImageView.centerXAnchor.constraint(equalTo: self.base.centerXAnchor).isActive = true
        placeHolderImageView.centerYAnchor.constraint(equalTo: self.base.centerYAnchor).isActive = true
        
        return placeHolderImageView
    }

    private func hidePlaceHolder(imageView: UIImageView?) {
        imageView?.removeFromSuperview()
    }
    
}
