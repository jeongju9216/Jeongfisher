//
//  UIImageView.swift
//  JeongImageCache
//
//  Created by jeongju.yu on 2023/02/20.
//

import UIKit
import Combine

extension UIImageView {
    
    ///url을 이용해 UIImage 설정
    ///
    ///- Parameters:
    ///     - url: 이미지 URL
    ///     - placeHolder: 이미지 다운로드 지연 시 보여줄 placeHolder
    ///     - watiPlaceHolderTime: placeHolde를 보여주기까지의 대기 시간
    ///     - useCache: 캐시 사용 여부 결정. false면 네트워크를 통해 이미지 다운로드
    public func setImageUsingJIC(url: String,
                          placeHolder: UIImage? = nil,
                          waitPlaceHolderTime: TimeInterval = 1,
                          useCache: Bool = true) {
        var placeHolderImageView: UIImageView?
        var placeHolderTimer: Cancellable?
        
        if let placeHolder = placeHolder {
            placeHolderTimer = Timer.publish(every: waitPlaceHolderTime, on: .main, in: .default)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    
                    JICLogger.log("Show PlaceHolder Timer")
                    placeHolderImageView = self.showPlaceHolder(image: placeHolder)
                }
        }
        
        Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let imageData: JeongImageData? = useCache ? await JeongImageCache.shared.getImageWithCache(url: url)
                                                 : await JeongImageCache.shared.getImageFromNetwork(url: url)
            
            if placeHolder != nil {
                placeHolderTimer?.cancel()
                hidePlaceHolder(imageView: placeHolderImageView)
            }
            
            if let imageData = imageData, let image = imageData.data.convertToImage() {
                self.image = JeongImageProcessor.shared.resizedImage(image, newSize: self.frame.size)
            } else {
                self.image = nil
            }
            
            let endTime = CFAbsoluteTimeGetCurrent() - startTime
            JICLogger.log("[Time] setImageUsingJIC: \(endTime)")
        }
    }
    
    ///진행 중인 URL 다운로드 취소
    ///
    ///- Parameters:
    ///     - url: 이미지 URL
    public func cacnelDownloadImageWithJIC(url: String) {
        JeongImageDownloader.shared.cancelDownloadImage(url: url)
    }
    
    private func showPlaceHolder(image: UIImage) -> UIImageView {
        let placeHolderImageView = UIImageView(image: image)
        placeHolderImageView.contentMode = .scaleAspectFit
        
        self.addSubview(placeHolderImageView)
        placeHolderImageView.translatesAutoresizingMaskIntoConstraints = false

        placeHolderImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        placeHolderImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        return placeHolderImageView
    }

    private func hidePlaceHolder(imageView: UIImageView?) {
        imageView?.removeFromSuperview()
    }
}
