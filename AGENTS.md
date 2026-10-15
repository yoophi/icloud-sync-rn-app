# 프로젝트 목적

- 이 프로젝트는 React Native 앱에서 iCloud Sync 기능을 검증하기 위한 PoC다.
- React Native Community CLI로 생성한 네이티브 앱과 pnpm workspace 모노레포 구성을 유지한다.
- 기본 React Native UI와 단순한 표준 컨트롤을 사용한다. 과도한 디자인, 시각적 장식, 별도 디자인 시스템 도입은 필요하지 않다.
- 기능 구현과 검증은 iCloud 동기화의 실현 가능성 및 동작 확인에 집중한다.

# 구조 및 실행

- `apps/mobile`: iOS 및 Android React Native 앱.
- `packages/typescript-config`: 공통 TypeScript 설정.
- 루트에서 `pnpm install`, `pnpm start`, `pnpm ios`, `pnpm android`를 실행한다.
- 변경 후 관련 검증을 수행한다. 기본 검증 명령은 `pnpm lint`, `pnpm typecheck`, `pnpm test`다.
