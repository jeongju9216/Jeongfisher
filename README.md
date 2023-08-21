# Jeongfisher
이미지 캐시 라이브러리입니다.  
Swift Concurrency를 적극 활용하여 개발하였습니다.  
노션 페이지 : https://jeong9216.notion.site/CloneStore-JeongImageCache-91f1964617b84c5d8df7da17f1b1d9db  

# 기능
1. 이미지 캐싱
2. 이미지 다운로드
3. 이미지 다운샘플링
4. 메모리 캐시 클래스
5. 디스크 캐시 클래스


# 설치
`Swift Package Manager(SPM)`을 지원합니다.  
```
https://github.com/jeongju9216/Jeongfisher.git
```
# 사용법

## 1. 이미지 캐싱

### url
`URL`을 이용해 이미지를 다운로드, 캐싱합니다.  
표시할 이미지 `URL`을 전달하세요.  
`다운샘플링` 이미지를 `UIImageView`에 설정합니다.  
``` swift
imageView.jf.setImage(with: url)
```

`원본` 이미지를 설정하고 싶다면 `showOriginalImage` 옵션 또는 `setOriginalImage(with:)`를 사용하세요.
```swift
posterImageView.jf.setImage(with: url, options: [.showOriginalImage])
```
```swift
posterImageView.jf.setOriginalImage(with: url)
```

### placeholder
네트워크 요청 후 n초 뒤 표시할 `placeholder`를 설정할 수 있습니다.  
기본 값은 `nil` 입니다.  
`nil`인 경우 `placeholder`가 표시되지 않습니다.  
``` swift
let placeHolder = UIImage(...)
imageView.jf.setImage(with: url, placeHolder: placeHolder)
```

### waitPlaceHolderTime
`placeholder` 대기 시간을 설정할 수 있습니다.  
`waitPlaceHolderTime`로 `TimeInterval(초 단위)`를 전달하세요.  
기본 값은 `1초`입니다.
``` swift
let placeHolder = UIImage(...)
imageView.jf.setImage(with: url,
                      placeHolder: placeHolder,
                      waitPlaceHolderTime: 3.0)
```

### options
이미지 설정에 부가적인 옵선을 설정할 수 있습니다.  
- cacheMemoryOnly
  - 메모리 캐시만 사용하고, 디스크 캐시를 사용하지 않습니다.
- onlyFromCache
  - 캐시 데이터만 사용합니다.
  - 캐시에 없어도 네트워킹을 하지 않습니다.
- forceRefresh
  - 항상 네트워킹을 합니다.
  - 캐시를 사용하지 않습니다.
- showOriginalImage
  - 다운샘플링을 하지 않습니다.
- disableETag
  - ETag를 확인하지 않습니다.
