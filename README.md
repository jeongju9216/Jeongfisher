# JeongImageCache
이미지 캐시를 지원하는 라이브러리입니다.  
노션 페이지 : https://jeong9216.notion.site/CloneStore-JeongImageCache-91f1964617b84c5d8df7da17f1b1d9db  

# 기능
1. 이미지 캐싱
2. 이미지 다운로드
3. 이미지 리사이징
4. 메모리 캐시 클래스
5. 디스크 캐시 클래스

## 업데이트 예정
1.0.0 버전은 다운로드한 이미지를 imageView Size로 리사이징하여 표시합니다.  
적은 메모리 사용량으로 이미지를 표시할 수 있습니다.  
리사이징이 불필요한 사용자를 위해 다음 버전에서 옵션으로 수정할 예정입니다.  

# 설치
Swift Package Manager(SPM)을 지원합니다.  
```
https://github.com/jeongju9216/JeongImageCache.git
```

# 사용법
## 이미지 캐싱
UIImageView extension을 이용해 이미지 캐싱을 할 수 있습니다.  
setImageUsingJIC에 url String을 전달하세요.  

``` swift
let imageURLString: String = "https://example.com/image.png"
imageView.setImageUsingJIC(url: imageURLString)
```

#### PlaceHolder
네트워크 통신이 길어지면 PlaceHolder를 보여줄 수 있습니다.  
placeHolder 파라미터로 UIImage?를 전달하세요.  
기본값은 nil이며, placeHolder가 nil인 경우 PlaceHolder를 표시하지 않습니다.
``` swift
let placeHolder = UIImage(systemName: "circle.dotted")
imageView.setImageUsingJIC(url: imageURLString, placeHolder: placeHolder)
```
  
#### waitPlaceHolderTime  
메서드 호출 n초 후 PlaceHolder를 표시합니다. (n: waitPlaceHolderTime)  
waitPlaceHolderTime 파라미터로 TimeInterval 타입을 전달하세요.
기본값은 1초입니다.
``` swift
imageView.setImageUsingJIC(url: imageURLString, placeHolder: placeHolder, waitPlaceHolderTime: 3.0)
```

#### useCache
캐시 사용 여부를 결정할 수 있습니다.  
항상 네트워크를 사용하고 싶다면 useCache 파라미터로 false를 전달하세요.
``` swift
imageView.setImageUsingJIC(url: imageURLString, useCache: false)
```
