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
            var placeHolderImageView: UIImageView?
            var placeHolderTimer: Cancellable?
            
            if let placeHolder = placeHolder {
                placeHolderTimer = Timer.publish(every: waitPlaceHolderTime, on: .main, in: .default)
                    .autoconnect()
                    .first()
                    .sink { _ in
                        placeHolderImageView = self.showPlaceHolder(image: placeHolder)
                    }
            }
                        
            if placeHolder != nil {
                placeHolderTimer?.cancel()
                hidePlaceHolder(imageView: placeHolderImageView)
            }
            
            let jfImageData = await JFImageCache.shared.getImageWithCache(url: url.absoluteString, usingETag: false)
            guard let jfImageData = jfImageData else {
                DispatchQueue.main.async {
                    print("HERE!!!! image is nil")
                    self.base.image = nil
                }
                return
            }

            DispatchQueue.main.async {
                let downsamplingImage = jfImageData.data.downsampling(to: self.base.frame.size)
                self.base.image = downsamplingImage
            }

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
