//
//  UIImageView+JF.swift
//  Jeongfisher
//
//  Created by 유정주 on 2023/08/11.
//

import UIKit

private struct JFAssociatedKeys {
    static var downloadUrl = "downloadUrl"
}

extension JeongfisherWrapper where Base: UIImageView {
    
    private var downloadUrl: String? {
        get {
            getAssociatedObject(base, &JFAssociatedKeys.downloadUrl)
        }
        set {
            setRetainedAssociatedObject(base, &JFAssociatedKeys.downloadUrl, newValue)
        }
    }
    
    ///url을 이용해 UIImage 설정
    ///
    ///- Parameters:
    ///     - url: 이미지 URL
    ///     - placeHolder: 이미지 다운로드 지연 시 보여줄 placeHolder
    ///     - watiPlaceHolderTime: placeHolde를 보여주기까지의 대기 시간
    ///     - useCache: 캐시 사용 여부 결정. false면 네트워크를 통해 이미지 다운로드
    public func setImage(
        with url: URL,
        placeHolder: UIImage? = nil,
        waitPlaceHolderTime: TimeInterval = 1.0,
        useCache: Bool = true)
    {
        Task {
            let timer: Timer? = createPlaceHolderTimer(placeHolder, waitTime: waitPlaceHolderTime)
            timer?.fire()
            
            var mutableSelf = self
            mutableSelf.downloadUrl = url.absoluteString
            
            let updatedImageData = await fetchImage(with: url, useCache: useCache)
            
            timer?.invalidate()
            
            if let downsampledImage = await updatedImageData?.data.downsampling(to: self.base.frame.size) {
                updateImage(downsampledImage)
            } else {
                updateImage(updatedImageData?.data.convertToImage())
            }
            
            mutableSelf.downloadUrl = nil
        }
    }
    
    private func fetchImage(with url: URL, useCache: Bool) async -> JFImageData? {
        if useCache,
            let jfImageData = await JFImageCache.shared.getImageWithCache(url: url) {
            return jfImageData
        } else {
            return try? await JFImageDownloader.shared.downloadImage(from: url)
        }
    }

    private func updateImage(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.base.image = image
        }
    }
    
    ///진행 중인 URL 다운로드 취소
    ///
    ///- Parameters:
    ///     - url: 이미지 URL
    public func cancelDownloadImage() {
        guard let downloadUrlString = downloadUrl,
              let url = URL(string: downloadUrlString) else { return }
        
        Task {
            await JFImageDownloader.shared.cancelDownloadImage(url: url)
        }
    }
}

private extension JeongfisherWrapper where Base: UIImageView {
    func createPlaceHolderTimer(_ placeHolder: UIImage?, waitTime: TimeInterval) -> Timer? {
        guard let placeHolder = placeHolder else { return nil }
        
        let timer = Timer.scheduledTimer(withTimeInterval: waitTime, repeats: true) { _ in
            showPlaceHolder(image: placeHolder)
        }
        
        return timer
    }
    
    func showPlaceHolder(image: UIImage) {
        DispatchQueue.main.async {
            self.base.image = image
        }
    }
}

private extension JeongfisherWrapper {
    func getAssociatedObject<T>(_ object: Any, _ key: UnsafeRawPointer) -> T? {
        return objc_getAssociatedObject(object, key) as? T
    }

    func setRetainedAssociatedObject<T>(_ object: Any, _ key: UnsafeRawPointer, _ value: T) {
        objc_setAssociatedObject(object, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
