# iCloud Sync React Native PoC

React Native 앱에서 iCloud Sync의 실현 가능성과 동기화 동작을 검증하는 PoC입니다. 기본 UI를 사용하며, 현재는 Community CLI 기본 앱과 pnpm 모노레포 초기 구성 단계입니다. iCloud 동기화 기능은 아직 구현하지 않았습니다.

## 구성

- `apps/mobile`: React Native 0.87.1 / React 19.2.3, iOS 및 Android 네이티브 프로젝트
- `packages/typescript-config`: 앱이 workspace 의존성으로 사용하는 공통 TypeScript 설정
- `pnpm-workspace.yaml`: workspace 정의
- `.npmrc`: 네이티브 도구가 루트 의존성을 사용하도록 `node-linker=hoisted` 설정

Metro는 저장소 루트를 감시하고 Android Gradle 설정은 루트 `node_modules`를 참조합니다. iOS Podfile은 Node의 모듈 탐색을 사용해 React Native를 찾습니다.

## 준비

Node.js 22.11 이상, pnpm 9.15.5를 사용합니다. iOS는 Xcode와 Ruby/Bundler/CocoaPods, Android는 JDK 17과 Android SDK가 필요합니다.

```sh
pnpm install

# iOS 네이티브 의존성 설치
pnpm pods
```

## 실행

```sh
# 터미널 1
pnpm start

# 터미널 2: iOS Simulator 또는 Android 에뮬레이터/기기
pnpm ios
pnpm android
```

앱 이름은 `ICloudSync`, 표시 이름은 `iCloud Sync`, bundle ID/application ID는 `com.yoophi.icloudsync`입니다. 실제 iCloud 검증 시 Apple Developer 팀, iCloud capability와 컨테이너, 서명 설정이 필요합니다.

## 검증

```sh
pnpm lint
pnpm typecheck
pnpm test
```

## 초기 생성

[React Native Community CLI](https://github.com/react-native-community/cli)의 기본 템플릿을 다음 명령으로 생성한 후 workspace 구성을 적용했습니다.

```sh
pnpm dlx @react-native-community/cli@20.2.0 init ICloudSync \
  --directory apps/mobile \
  --title 'iCloud Sync' \
  --package-name com.yoophi.icloudsync \
  --skip-install --install-pods false --skip-git-init
```
