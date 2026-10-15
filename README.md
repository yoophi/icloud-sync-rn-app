# iCloud Sync React Native PoC

React Native 기반 iPhone 및 macOS 앱에서 iCloud를 통한 저장 및 동기화 기능을 검증하는 PoC입니다. 기본 UI를 사용합니다.

핵심 검증 목표는 **iCloud 파일 시스템에서 사진과 텍스트 파일을 생성하고 관리하는 기능이 정상 동작하는지 확인하는 것**입니다. 마크다운 파일 생성·단순 텍스트 편집·목록 보기와 이미지 파일 등록·보기·삭제에 집중합니다. PoC이므로 과도한 기능 구현, 보안 강화, 성능 최적화는 범위에 포함하지 않습니다.

## 목표 기능

- iPhone 앱과 React Native macOS 앱을 제공합니다.
- 사진과 텍스트 문서를 저장합니다.
- 저장한 사진과 텍스트 문서를 iCloud를 통해 동기화합니다.

마크다운 파일 생성·목록·단순 텍스트 편집과 사진 등록·보기·삭제를 구현했습니다. 파일은 iCloud Documents 컨테이너에 저장하며, 동기화는 iCloud Drive가 처리합니다. iCloud 연결이 없으면 오류를 표시합니다. 실제 기기 간 동기화 검증은 아직 완료되지 않았습니다. macOS 서명 빌드와 앱 실행은 확인했으나, 현재 iCloud `Documents` 폴더 생성 시 쓰기 권한 거부가 발생해 추가 진단이 필요합니다.

## 구성

- `apps/mobile`: React Native 0.87.1 / React 19.2.3 기반 iPhone 앱. Android 프로젝트는 CLI가 생성한 초기 템플릿으로 남아 있으며 지원 대상이 아닙니다.
- `apps/macos`: React Native macOS 0.83.0 / React Native 0.83.10 기반 Mac 앱 (macOS 14 이상)
- `packages/typescript-config`: 앱이 workspace 의존성으로 사용하는 공통 TypeScript 설정
- `pnpm-workspace.yaml`: workspace 정의
- `.npmrc`: 네이티브 도구가 루트 의존성을 사용하도록 `node-linker=hoisted` 설정

Metro는 저장소 루트를 감시하고 Android Gradle 설정은 루트 `node_modules`를 참조합니다. iOS Podfile은 Node의 모듈 탐색을 사용해 React Native를 찾습니다.

## 준비

Node.js 22.11 이상, pnpm 9.15.5, Xcode와 Ruby/Bundler/CocoaPods가 필요합니다.

```sh
pnpm install

# iOS 네이티브 의존성 설치
pnpm pods
```

## 실행

```sh
# 터미널 1
pnpm start

# 터미널 2: iPhone Simulator 또는 iPhone 기기
pnpm ios
```

앱 이름은 `ICloudSync`, 표시 이름은 `iCloud Sync`, bundle ID/application ID는 `com.yoophi.icloudsync`입니다. 실제 iCloud 검증 시 Apple Developer 팀, iCloud capability와 컨테이너, 서명 설정이 필요합니다.

## 검증

```sh
pnpm lint
pnpm typecheck
pnpm test
pnpm test:native # macOS + Xcode Command Line Tools 필요
pnpm check:ios # CocoaPods 설치 후 iOS 네이티브 모듈 검사
```

실제 iPhone의 서명·컨테이너 설정, 검증 절차와 결과는 [iCloud PoC 검증 문서](docs/icloud-poc-validation.md)를 참고하세요. 기본 컨테이너는 `iCloud.com.yoophi.icloudsync`이며 Xcode의 `ICLOUD_CONTAINER_IDENTIFIER` 설정으로 변경할 수 있습니다.

## 초기 생성

[React Native Community CLI](https://github.com/react-native-community/cli)의 기본 템플릿을 다음 명령으로 생성한 후 workspace 구성을 적용했습니다.

```sh
pnpm dlx @react-native-community/cli@20.2.0 init ICloudSync \
  --directory apps/mobile \
  --title 'iCloud Sync' \
  --package-name com.yoophi.icloudsync \
  --skip-install --install-pods false --skip-git-init
```

## macOS PoC

```sh
pnpm install
pnpm pods:macos
pnpm start:macos # 별도 터미널, Metro 8082
pnpm macos      # 별도 터미널
pnpm check:macos # 서명 없이 네이티브 컴파일·링크 검사
```

Xcode의 `apps/macos/macos/ICloudSyncMac.xcworkspace`에서 개발 팀을 선택하고,
iPhone 앱과 같은 `iCloud.com.yoophi.icloudsync` 컨테이너를 연결합니다.
Mac의 bundle ID는 `com.yoophi.icloudsync.macos`입니다.
이미지는 macOS 파일 선택 창에서 등록하며 마크다운은 원문으로 편집합니다.

두 앱의 RN 버전은 플랫폼 지원 범위에 맞춰 분리했습니다. Metro·CLI·Jest도 각 앱의
RN을 참조합니다. iPhone Metro는 8081, Mac Metro는 8082를 사용합니다.
Foundation 기반 `CloudDocuments.swift`는 iPhone 소스를 Mac target에서도 직접 컴파일합니다.

서명 설정과 기기 간 확인 절차는 [macOS PoC 검증 문서](docs/macos-poc-validation.md)를 참고하세요.
