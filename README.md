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
``` swift
imageView.jf.setImage(with: url)
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

### useCache
캐시 사용 여부를 설정할 수 있습니다.  
기본 값은 `true`입니다.  
`true`인 경우, 메모리 캐시, 디스크 캐시를 사용합니다.  
`false`인 경우, 네트워크 다운로드만 사용합니다.  
``` swift
imageView.jf.setImage(with: url, useCache: true) //메모리 캐시, 디스크 캐시, 네트워크 다운로드 사용
imageView.jf.setImage(with: url, useCache: false) //네트워크 다운로드만 사용
```

### useETag
`eTag` 사용 여부를 설정할 수 있습니다.  
기본 값은 `false`입니다.  
서버에서 `eTag`를 지원하는 경우에만 `true`로 설정하세요.  
``` swift
imageView.jf.setImage(with: url, useETag: true) //eTag 사용
imageView.jf.setImage(with: url, useETag: false) //eTag 미사용
```
