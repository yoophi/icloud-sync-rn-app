# iCloud 파일 PoC 검증

## 목표와 범위

iPhone의 iCloud Documents 파일 시스템에서 마크다운 파일 생성·원문 편집·목록 보기와 이미지 등록·보기·삭제가 정상 동작하는지 확인한다. 기본 UI를 사용한다. 추가 기능, 보안 강화, 성능 최적화는 범위에서 제외한다.

## 구현

- 기본 컨테이너: `iCloud.com.yoophi.icloudsync`, 앱 bundle ID: `com.yoophi.icloudsync`.
- `FileManager.url(forUbiquityContainerIdentifier:)`가 반환한 컨테이너의 `Documents` 디렉터리에 실제 파일을 생성한다. iCloud 접근이 실패하면 오류를 표시한다.
- `NSFileCoordinator`로 읽기·쓰기·삭제를 조정한다. 미다운로드 파일은 다운로드를 요청하고 조정된 읽기로 연다.
- 목록은 `NSMetadataQuery`의 iCloud 문서 검색 결과와 디렉터리 내용을 합쳐 표시한다. 목록 새로고침 또는 앱 복귀 시 다시 조회한다.
- 마크다운은 UTF-8 `.md` 파일로 저장하며 원문을 단순 텍스트로 편집한다. 같은 이름으로 생성하면 오류를 반환한다.
- 사진은 시스템 사진 선택기에서 한 장을 선택하고 고유 파일 이름으로 복사한다. 보기 시 iCloud 원본에서 캐시 사본을 만들어 표시한다. 삭제는 iCloud 원본에 적용한다.
- 저장 성공은 파일 쓰기 성공을 뜻한다. 업로드·기기 간 전파 완료와 같지 않으며, iCloud 동기화는 운영체제가 처리한다.

파일 발견과 컨테이너 접근 방식은 Apple의 [iCloud File Management](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html)를 따른다. 조정된 읽기는 다운로드를 기다리며, 메타데이터만 즉시 읽는 옵션과의 차이는 [NSFileCoordinator 읽기 옵션](https://developer.apple.com/documentation/foundation/nsfilecoordinator/readingoptions/immediatelyavailablemetadataonly)에 설명되어 있다.

## 실제 iPhone 준비

1. Xcode에서 `apps/mobile/ios/ICloudSync.xcworkspace`를 연다.
2. `ICloudSync` target의 Signing & Capabilities에서 iCloud capability를 사용할 수 있는 Apple Developer 팀을 선택한다.
3. iCloud capability의 iCloud Documents를 활성화하고 팀에 등록된 컨테이너를 연결한다. 기본 ID가 사용 불가능하면 Build Settings의 `ICLOUD_CONTAINER_IDENTIFIER`를 변경한다. 이 값은 entitlements와 Info.plist에 함께 적용된다.
4. 동일한 Apple 계정의 iPhone 두 대에서 iCloud Drive를 켜고 이 앱의 iCloud 사용을 허용한다.
5. 두 기기에 같은 컨테이너 설정으로 빌드한 앱을 설치한다. 개발 모드와 네트워크 연결을 확인한다. Debug 앱은 `pnpm start`로 실행한 Metro에 연결한다.

## 기기 검증 절차

| 검증 항목 | 절차 | 기대 결과 |
| --- | --- | --- |
| 연결 | 앱 실행 후 목록 새로고침 | iCloud Drive 연결됨 표시 |
| 문서 생성 | A에서 `sample` 이름으로 `# 제목`과 한글 본문을 입력하고 저장 | `sample.md`가 목록에 나타남 |
| 문서 읽기 | A에서 파일을 다시 열고 앱 재실행 후 다시 열기 | 원문과 한글 내용이 동일함 |
| 문서 수정 | A에서 원문 수정 후 저장 | 다시 열면 수정 내용 유지 |
| 문서 동기화 | 업로드 후 B에서 목록 새로고침하고 파일 열기 | 생성한 파일 및 최종 내용 확인 |
| 역방향 수정 | B에서 같은 문서 수정, A에서 다시 새로고침하고 열기 | B의 수정 내용 확인 |
| 사진 등록 | A에서 사진 등록을 누르고 사진 선택 | 이미지 파일이 목록에 나타남 |
| 사진 보기 | A 및 B에서 목록 새로고침 후 이미지 선택 | 저장한 이미지가 표시됨. 다운로드가 필요한 경우 완료 후 표시 |
| 사진 삭제 | A에서 이미지 삭제 확인 후 B에서 목록 새로고침 | 양쪽 목록에서 이미지 제거 |
| 선택 취소 | 사진 선택기에서 취소 | 파일이 추가되지 않음 |
| iCloud 불가 | iCloud Drive가 꺼진 별도 테스트 환경에서 실행 | 오류 표시, 로컬 저장 성공으로 처리하지 않음 |

기기 검증 시 iOS 버전, 컨테이너 ID, 실행 시각, 결과 및 실패 메시지를 기록한다. 동시 편집 충돌 해결은 이번 PoC의 범위가 아니다. 다른 기기에서 변경된 파일은 편집을 닫고 목록을 새로고침한 후 다시 연다.

## 자동 검증

```sh
pnpm lint
pnpm typecheck
pnpm test
pnpm test:native
pnpm check:ios # pnpm pods 실행 후, 설치된 iOS SDK로 네이티브 모듈 검사
```

`pnpm test`는 네이티브 API를 mock한 React 화면 동작 검증이다. `pnpm test:native`는 macOS의 임시 디렉터리에서 실제 `NSFileCoordinator`와 파일 IO를 사용한다. 둘 다 실제 iCloud 통신을 검증하지 않는다.

## 검증 결과 (2026-10-15)

- lint 및 TypeScript 검사: 통과.
- React 화면 동작: 7개 테스트 통과. 목록, 마크다운 생성·편집, 저장 실패 시 원문 보존, 이미지 등록·보기·삭제 확인, 선택 취소, iCloud 불가 처리를 검증했다.
- Swift 파일 IO: 통과. 한글 UTF-8 원문 저장·수정·읽기, 중복 생성 및 없는 파일 수정 오류, 이미지 import·preview·delete, placeholder 및 metadata 파일 목록을 검증했다.
- iOS SDK와 실제 React Native 헤더를 사용한 Swift 모듈 타입 검사 및 Objective-C 브리지 문법 검사: 통과.
- arm64 iOS 네이티브 의존성 빌드: 통과. LaunchScreen storyboard를 제외한 앱 코드 컴파일·링크도 통과했으며, Swift에서 내보낸 selector와 Objective-C 브리지 선언의 일치를 확인했다. 이 우회 빌드는 전체 앱 빌드 성공으로 간주하지 않는다.
- 전체 iOS 빌드와 기기 간 iCloud 검증: 진행 중. 최초 빌드는 Xcode의 `iOS 26.2 Platform Not Installed` 오류로 컴파일 전에 중단됐다. 사용 가능한 iPhone이 없고, 서명 팀도 지정되지 않았다.
