# macOS iCloud 파일 PoC

## 범위와 구성

macOS 14 이상에서 마크다운 생성·목록·원문 편집, 이미지 파일 등록·보기·삭제를 검증한다.
React Native macOS의 표준 컨트롤과 AppKit의 `NSOpenPanel`을 사용한다.
별도 디자인 시스템, 리치 텍스트/미리보기, 충돌 해결, 보안 강화, 성능 최적화는 추가하지 않는다.

- 앱: `apps/macos`, React Native macOS 0.83.0 + React Native 0.83.10 + React 19.2.3.
- iPhone 앱은 기존 RN 0.87.1을 유지한다. CLI·Metro·Jest가 각 플랫폼의 RN을 참조한다.
- Xcode workspace: `apps/macos/macos/ICloudSyncMac.xcworkspace`, scheme: `ICloudSyncMac-macOS`.
- bundle ID: `com.yoophi.icloudsync.macos`.
- 기본 컨테이너: `iCloud.com.yoophi.icloudsync`, iPhone과 동일하다.
- Xcode Build Settings의 `ICLOUD_CONTAINER_IDENTIFIER`는 Info.plist와 entitlements에 함께 적용된다.
- Mac target은 `apps/mobile/ios/ICloudSync/CloudDocuments.swift`를 직접 컴파일해 파일 형식과 저장 방식을 공유한다.
- 파일은 컨테이너의 `Documents`에 저장한다. iCloud 접근 실패 시 오류를 표시하며 로컬 저장으로 대체하지 않는다.
- 목록은 `NSMetadataQuery`와 디렉터리 내용을 합친다. 수동 새로고침·앱 복귀 시 갱신하며, 다른 기기의 변경은 편집을 닫고 파일을 다시 열어 확인한다.
- 이미지 선택 취소 시 파일을 만들지 않는다. 선택 파일은 접근 권한이 유효할 때 iCloud로 복사한다.
- 저장 성공과 iCloud 업로드 완료는 다르다. 동기화 전파는 운영체제가 처리한다.

버전은 [React Native macOS 패키지](https://www.npmjs.com/package/react-native-macos)의 peer dependency에 맞춘다.
초기 네이티브 프로젝트는 Microsoft가 배포한 `react-native-macos@0.83.0`의 `local-cli/generator-macos` 템플릿에서 생성했다.

## 실행

Node 22.11 이상, pnpm 9.15.5, Xcode 및 Ruby/Bundler/CocoaPods가 필요하다.
Ruby는 프로젝트 Gemfile.lock의 3.2.3 환경을 사용할 수 있다. `ruby`와 `bundle`이 같은 Ruby 설치를 가리키는지 확인한다.

```sh
pnpm install
pnpm pods:macos

# 터미널 1: Mac 전용 Metro
pnpm start:macos

# 터미널 2: 앱 빌드 및 실행
pnpm macos
```

Mac Metro는 8082, iPhone Metro는 기존 8081을 사용하므로 함께 실행할 수 있다.
실제 iCloud 접근에는 다음 서명 설정이 필요하다. 서명 없는 빌드 검사는 이 설정을 대신하지 않는다.

1. Xcode에서 위 workspace를 열고 `ICloudSyncMac-macOS` target의 개발 팀을 선택한다.
2. Signing & Capabilities에서 iCloud Documents 및 iPhone과 같은 컨테이너를 연결한다.
3. 다른 컨테이너를 사용하면 양쪽 target의 `ICLOUD_CONTAINER_IDENTIFIER`를 같은 값으로 변경한다.
4. Mac과 iPhone에 같은 Apple 계정으로 로그인하고 iCloud Drive를 켠다.
5. 각 앱을 해당 팀과 컨테이너의 프로비저닝으로 서명하여 실행한다.

## 기기 간 확인

| 확인 | 절차 | 기대 결과 |
| --- | --- | --- |
| 연결 | 양쪽 앱에서 목록 새로고침 | 연결됨, 동일 컨테이너 파일 목록 |
| Mac → iPhone 문서 | Mac에서 `mac-note` 생성, 한글과 마크다운 원문 저장 | iPhone 새로고침 후 `mac-note.md` 원문 확인 |
| iPhone → Mac 문서 | iPhone에서 원문 수정 후 저장 | Mac 편집 닫기·새로고침·다시 열기 후 수정 내용 확인 |
| Mac → iPhone 이미지 | Mac에서 PNG/JPEG 파일 등록 | 양쪽에서 이미지 열기 가능 |
| iPhone → Mac 이미지 | iPhone에서 사진 등록 | Mac 새로고침 후 이미지 표시 |
| 삭제 | Mac에서 이미지 삭제를 확인 | 양쪽 목록에서 제거 |
| 선택 취소 | Mac 이미지 선택 창 취소 | 새 파일 없음 |
| 저장 실패 | 같은 이름으로 새 마크다운 생성 | 오류 표시 및 입력 내용 유지 |
| 연결 불가 | iCloud를 사용하지 않는 별도 테스트 환경에서 실행 | 오류 표시, 생성·등록 비활성화 |

기기별 OS, 시각, 컨테이너 ID와 결과를 기록한다. 동시에 같은 파일을 편집하는 상황은 이번 검증 범위에서 제외한다.

## 자동 검증

```sh
pnpm lint
pnpm typecheck
pnpm test
pnpm test:native
pnpm check:macos
```

화면 테스트는 네이티브 API mock으로 각 앱의 목록·편집·이미지 흐름과 오류를 확인한다.
Swift 테스트는 임시 디렉터리에서 실제 NSFileCoordinator와 파일 IO를 확인한다.
`check:macos`는 Apple 개발 서명 없이 실제 macOS 앱과 네이티브 모듈을 컴파일·링크한다.
이 검사들은 실제 iCloud 서버와 기기 간 전파 성공을 증명하지 않는다.

## 검증 결과 (2026-10-15)

- lint·TypeScript: 통과.
- 화면 테스트: Mac 7개, iPhone 7개 통과.
- 공통 Swift 파일 처리: UTF-8 문서 생성·읽기·수정, 중복/없는 파일 오류, 이미지 등록·캐시 복사·삭제, placeholder/metadata 목록 처리 통과.
- Mac 및 iPhone Metro 배포용 JavaScript 번들 생성: 통과. iPhone 번들의 RN 소스가 모바일 RN 0.87.1만 참조함을 확인.
- CocoaPods 설치: 통과.
- macOS 전체 네이티브 빌드: arm64 Debug 컴파일·링크 통과 (`CODE_SIGNING_ALLOWED=NO`).
- 실제 Mac 앱 실행: Metro 8082로 화면 표시 및 네이티브 모듈 로딩 확인. 서명 없는 실행에서는 컨테이너 접근 오류 안내와 생성·등록 비활성화를 확인.
- 실제 iPhone ↔ Mac iCloud 동기화: 미검증. 개발 팀 서명과 양쪽 기기에서 위 절차를 수행해야 한다.

## 후속 개발 서명 빌드 (2026-10-15)

- 사용자가 조직 개발 팀으로 변경한 현재 설정으로 Debug 재빌드 성공. 기존 Personal Team 오류는 이번 빌드에서 재현되지 않았다.
- `codesign --verify --deep --strict` 통과. 실행 바이너리의 개발 팀, `iCloud.com.yoophi.icloudsync` 컨테이너와 `CloudDocuments` entitlement 확인.
- 빌드 성공은 실제 컨테이너 접근이나 기기 간 동기화 성공을 의미하지 않는다. 실행 중인 이전 앱은 종료하고 새 빌드를 실행해 검증해야 한다.

## 서명 앱 실행 후 남은 문제 (2026-10-15)

- 서명된 새 앱은 실행되지만 컨테이너의 `Documents` 폴더 생성에서 쓰기 권한 거부가 발생한다. 생성·등록 버튼은 비활성화 상태다.
- 앱과 프로비저닝 프로파일에 컨테이너 ID 및 iCloud Documents 권한이 포함돼 있음을 확인했다. 이전 Personal Team 제한과는 다른 실행 단계의 문제다.
- 같은 컨테이너에 대해 iCloud 시스템 로그에 `Zone Not Found`가 기록됐지만, 이 로그가 쓰기 거부의 직접 원인인지는 확정하지 못했다. 컨테이너 초기화 및 샌드박스 접근 상태를 추가 진단해야 한다.
- 현재 결과는 앱 구현·자동 테스트·빌드·서명 검증까지이며, 실제 컨테이너 쓰기와 기기 간 동기화 성공으로 간주하지 않는다.
