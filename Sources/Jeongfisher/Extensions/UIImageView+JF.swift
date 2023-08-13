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
    
    /// UIImageView가 사용한 URL
    private var downloadUrl: String? {
        get {
            getAssociatedObject(base, &JFAssociatedKeys.downloadUrl)
        }
        set {
            setRetainedAssociatedObject(base, &JFAssociatedKeys.downloadUrl, newValue)
        }
    }
    
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - placeHolder: 다운로드 지연 시 보여줄 placeHolder 이미지
    ///   - waitPlaceHolderTime: placeHolder 대기 시간
    ///   - useCache: 캐시 사용 여부. false면 네트워크 다운로드
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
    
    /// url 이미지를 가져오는 메서드
    /// memory cache -> disk cache -> network 순서로 진행됨
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - useCache: 캐시 사용 여부
    /// - Returns: url 처리 결과
    private func fetchImage(with url: URL, useCache: Bool) async -> JFImageData? {
        if useCache,
            let jfImageData = await JFImageCache.shared.getImageWithCache(url: url) {
            return jfImageData
        } else {
            return try? await JFImageDownloader.shared.downloadImage(from: url)
        }
    }
    
    /// main thread에서 UIImageView 이미지 업데이트
    /// - Parameter image: UIImageView에 넣을 UIImage
    private func updateImage(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.base.image = image
        }
    }
    
    /// 진행 중인 다운로드 취소
    public func cancelDownloadImage() {
        guard let downloadUrlString = downloadUrl,
              let url = URL(string: downloadUrlString) else { return }
        
        Task {
            await JFImageDownloader.shared.cancelDownloadImage(url: url)
        }
    }
}

private extension JeongfisherWrapper where Base: UIImageView {
    /// PlaceHolder를 보여주는 타이머 생성.
    /// 스크롤 도중에도 PlaceHolder를 보여줘야 하므로 DispatchQueue 사용
    /// - Parameters:
    ///   - placeHolder: 보여줄 PlaceHolder 이미지
    ///   - waitTime: Place Holder 대기 시간
    /// - Returns: Timer 반환
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
