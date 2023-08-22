# Jeongfisher
이미지 캐시 라이브러리입니다.  
Swift Concurrency를 적극 활용하여 개발하였습니다.  

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
<details>
<summary>옵션 목록</summary>
<div markdown="1">       
  
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
 
</div>
</details>

</br>

# 기술적 고민
<details>
<summary>⭐️ 다운샘플링 적용</summary>
<div markdown="1">       

### 관련 블로그 포스팅 (추천)
https://jeong9216.tistory.com/670

### 적용 이유
- `Jeongfisher`는 썸네일처럼 작은 이미지를 보여주는 용도로 적합함
- `Downsampling`을 기본으로 적용하여 `메모리 효율 증가` 효과를 기대함

### 적용 방법
- WWDC18 - Image and Graphics Best Practices에서 소개된 방법을 사용함

### 성능 비교
- 다운샘플링 이미지 설정과 원본 이미지 설정을 비교함
- XCTest에서 `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric` 옵션으로 성능을 측정함
- 1000x1000 이미지 설정을 100번 수행함

### 성능 비교 결과

#### `Clock Monotonic Time`
- 둘 다 0.00으로 동일
- <img width="1361" alt="ClockMonotonicTime" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/8cc0cbe4-910a-4897-8695-93b92049f3af">

#### `메모리 사용량`
- `다운샘플링`이 `8배` 낮았음
- 왼쪽이 다운샘플링, 오른쪽이 원본 이미지
- <img width="241" alt="다운샘플링 메모리" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/3f9a18ec-ee16-4d53-8b7f-5704941ed553"> <img width="237" alt="원본 메모리" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/b0737be8-6e00-4d67-82f2-8053079f2876">  

#### `Memory Peak Physical`
- `다운샘플링`이 `3MB` 더 낮았음
- <img width="1356" alt="Memory Peak Physical" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/21e974d4-e0eb-4853-a5d7-57faf2d5560c">

#### `Memory Physical`
- `다운샘플링`이 `3.113 kB`로 약 `4배` 더 낮았음
- <img width="1357" alt="Memory Physical" src="https://github.com/jeongju9216/Jeongfisher/assets/89075274/7bbdcb06-31b7-4cef-9c38-1c0e0ce5d0cc">

#### `CPU(CPU Cycles, CPU Instructions Retired, CPU Time)`
- 둘이 같았음

### 성능 비교 결론
- 메모리 측면에서 다운샘플링이 압도적으로 유리하고, 이외의 측면에서는 큰 차이는 없었음
- 다운샘플링 이미지는 화질 저하가 있으므로 UIImageView 크기가 커지면 원본 이미지 설정이 필요함
- 원본 이미지가 필요하면 `showOriginalImage` 옵션이나 `setOriginalImage` 메서드를 사용하면 되기 때문에 다운샘플링 적용은 좋은 결정이었다고 생각함

</div>
</details>

<details>
<summary>메모리 캐시 구현 - 자료구조 선택</summary>
<div markdown="1">      

### 관련 블로그 포스팅
https://jeong9216.tistory.com/671#자료구조-선택

### 배열과 링크드 리스트
- `배열`은 `원소 재배치 오버헤드`가 발생함
- Hit 데이터를 맨 앞으로 이동시키기 때문에 `배열`은 비효율적 (LRU 기준)
  - Hit 데이터를 맨 뒤로 보내도 동일함
  - 뒤에 넣는 경우에는 cost가 부족해졌을 때 앞의 원소를 삭제하므로 `원소 재배치 오버헤드`가 발생함
- 이 문제를 해결하기 위해 `링크드 리스트`로 구현
  - 원소 삭제를 효율적으로 하기 위해 `양방향 링크드 리스트`로 구현함
  - tail을 이용해 맨 뒤 원소에 바로 접근할 수 있어서 효율적임

### 딕셔너리(Dictionary)
- `링크드 리스트`의 `느린 탐색` 단점을 해소하기 위해 도입함
  - 메모리 캐시는 데이터를 빠르게 읽어야 하기 때문에 느린 탐색은 치명적인 단점
- `딕셔너리`를 사용하여 상수 시간복잡도로 데이터를 읽을 수 있음

</div>
</details>

<details>
<summary>메모리 캐시 구현 - 동시성 문제</summary>
<div markdown="1">      

### 관련 블로그 포스팅
https://jeong9216.tistory.com/671#동시성-문제

### 딕셔너리의 동시성 문제 해결
- `딕셔너리`는 Thread safe 하지 않음
  - 같은 키에 여러 thread가 동시에 접근하면 런타임 에러가 발생
- 이를 해결하기 위해 두 가지 방법을 고민함
 
- `DispatchQueue barrier` (기각)
  - 리턴이 있는 메서드에서 `completionHandler`를 사용해야 함
  - 리턴이 있는 메서드가 많았기 때문에 코드 복잡도가 높아질 것이라 판단하여 기각
 
- `NSLock` (채택)
  - 간단하면서 강력한 Lock을 지원
  - 처음에는 lock 효율을 위해 `좁은 범위`로 lock과 unlock을 수행함
  - "lock은 `안정성`이 최우선이다"라는 리뷰를 받고 `defer`를 활용해 메서드 단위로 lock을 수행함

</div>
</details>

<details>
<summary>디스크 캐시 구현 - ETag 적용</summary>
<div markdown="1">      

### 관련 포스팅
https://jeong9216.tistory.com/671#디스크-캐시

- 디스크 캐시의 `장기 보관` 특징을 극대화할 수 있는 방법을 고민함
- `ETag`를 활용하여 `장기 보관` 개선
- `ETag`가 동일하다면 `만료일을 갱신`해서 캐시 데이터 보관 기간을 늘림
- `ETag`를 지원하지 않거나 사용하지 않고 싶다면 옵션으로 비활성할 수도 있음

</div>
</details>

<details>
<summary>⭐️ JFImageDownloader 구현</summary>
<div markdown="1">      

### 관련 포스팅 (추천)
https://jeong9216.tistory.com/672

### 발생한 문제
- `중복 Request`를 처리하는 과정에서 문제가 있었음
  - 동일한 URL이 동시에 Request가 되면 첫 번째 Request만 처리됨
  - 예를 들어, 10개의 UIImageView가 동일한 URL을 Request 하면 1번 UIImageView에만 이미지가 설정되고 나머지 UIImageView에는 이미지 설정이 되지 않음
- `딕셔너리` 동시성 문제를 `DispatchQueue`로 해결해서 코드 복잡성이 증가함

### 해결 방법
- `actor`, `Task`, `Enum`, `async/await`을 활용하여 해결함
- `actor`는 동시성 문제르 해결하기 위해 적용
  - DispatchQueue를 없애면서 코드 가독성을 개선함
- `Task`와 `Enum`은 `중복 Request`를 처리하기 위해 적용
  - Enum 연관값으로 Task를 전달
  - 딕셔너리로 Enum을 관리
  - Enum 케이스를 변경하여 완료 처리
  - 중복 Request가 들어왔다면, Task의 value를 대기하고 완료되면 전달
 
### 개선 후 느낀 점
- 동일한 Request가 들어오면 첫 번째 Request 결과를 대기했다가 반환할 수 있게 됨
- `Swift Concurrency`가 코드 가독성에 큰 기여를 한다는 것을 다시 한 번 느낌
- `actor`가 처음에는 너무 어려웠지만, 직접 사용해보니 편하게 동시성 문제를 해결할 수 있다는 것을 배움

</div>
</details>

