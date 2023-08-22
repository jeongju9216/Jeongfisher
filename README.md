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

# 기술적 고민
## 다운샘플링 적용
### 적용 이유
- `Jeongfisher`는 썸네일처럼 작은 이미지를 보여주는 용도로 적합함
- `Downsampling`을 기본으로 적용하여 `메모리 효율 증가` 효과를 기대함

### 적용 방법
- WWDC18 - Image and Graphics Best Practices에서 소개된 방법을 사용함

### 다운샘플링과 원본 성능 비교
- XCTest에서 `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric` 옵션으로 성능을 측정함
- 1000x1000 이미지 설정을 100번 수행함

### 성능 비교 결과

`Clock Monotonic Time`
- 둘 다 0.00으로 동일
- <img width="1361" alt="ClockMonotonicTime" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/8cc0cbe4-910a-4897-8695-93b92049f3af">

`메모리 사용량`
- `다운샘플링`이 `8배` 낮았음
- 왼쪽이 다운샘플링, 오른쪽이 원본 이미지
- <img width="241" alt="다운샘플링 메모리" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/3f9a18ec-ee16-4d53-8b7f-5704941ed553"> <img width="237" alt="원본 메모리" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/b0737be8-6e00-4d67-82f2-8053079f2876">  

`Memory Peak Physical`
- `다운샘플링`이 `3MB` 더 낮았음
- <img width="1356" alt="Memory Peak Physical" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/21e974d4-e0eb-4853-a5d7-57faf2d5560c">

`Memory Physical`
- `다운샘플링`이 `3.113 kB`로 약 `4배` 더 낮았음
- <img width="1357" alt="Memory Physical" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/7bbdcb06-31b7-4cef-9c38-1c0e0ce5d0cc">

`CPU(CPU Cycles, CPU Instructions Retired, CPU Time)`
- 둘이 같았음

### 성능 비교 결론
- 메모리 측면에서 다운샘플링이 압도적으로 유리하고, 이외의 측면에서는 큰 차이는 없었음
- 다운샘플링 이미지는 화질 저하가 있으므로 UIImageView 크기가 커지면 원본 이미지 설정이 필요함
- 원본 이미지가 필요하면 `showOriginalImage` 옵션이나 `setOriginalImage` 메서드를 사용하면 되기 때문에 다운샘플링 적용은 좋은 결정이었다고 생각함




