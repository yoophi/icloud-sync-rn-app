# 프로젝트 목적

<!-- td-agent-instructions:start -->
<!-- td-agent-instructions:version=3 -->

## Working with td

td keeps task context durable across sessions. In a new context, run `td usage --new-session -q` to see current work.

Use your judgment about how much tracking a task needs. For substantive work: `td start <id>`, record progress with `td log`, hand off with `td handoff <id>`, then `td review <id>`.

Closing needs a review. Say who did it (default trusted mode; delegated/strict allow only the first):

- independent session: `td approve <id> --reason "..."`
- a sub-agent: `td approve <id> --reviewed-by "<who>"`
- you: `td approve <id> --self-review --reason "..."`

Prefer a reviewer with its own `TD_CONTEXT_ID`; never name one who did not review.

Run `td usage` or `td <command> --help`.

<!-- td-agent-instructions:end -->

- 긴 작업은 상위 항목을 epic으로 지정하고, td에 하위 task를 등록한 뒤 각 task의 진행 및 검증 결과를 기록한다.
- 이 프로젝트는 React Native 앱에서 iCloud Sync 기능을 검증하기 위한 PoC다.
- iPhone 앱과 macOS 앱을 제공하며, 핵심 검증 목표는 iCloud 파일 시스템에서 사진과 텍스트 파일을 생성하고 관리하는 기능이 정상 동작하는지 확인하는 것이다.
- 검증 범위는 마크다운 파일 생성·단순 텍스트 편집·목록 보기와 이미지 파일 등록·보기·삭제다.
- PoC이므로 과도한 기능 구현, 보안 강화, 성능 최적화는 고려하지 않고 요청한 기능의 동작 검증에 집중한다.
- React Native Community CLI로 생성한 네이티브 앱과 pnpm workspace 모노레포 구성을 유지한다.
- 기본 React Native UI와 단순한 표준 컨트롤을 사용한다. 과도한 디자인, 시각적 장식, 별도 디자인 시스템 도입은 필요하지 않다.
- 마크다운은 원문을 단순 텍스트로 편집한다. 리치 텍스트 편집기나 렌더링 미리보기는 도입하지 않는다.

# 구조 및 실행

- `apps/mobile`: iPhone 전용 React Native 앱. Android 디렉터리는 CLI 초기 템플릿이며 지원 대상이 아니다.
- `apps/macos`: React Native macOS 앱. iPhone과 동일한 iCloud 컨테이너를 사용한다.
- `packages/typescript-config`: 공통 TypeScript 설정.
- 루트에서 `pnpm install`, `pnpm start`, `pnpm ios`를 실행한다.
- macOS는 `pnpm pods:macos`, `pnpm start:macos`, `pnpm macos`로 준비·실행한다. Metro 포트는 iPhone 8081, macOS 8082다.
- macOS 네이티브 빌드는 `pnpm check:macos`로 검증한다. 실제 iCloud는 개발 팀과 컨테이너를 설정한 서명 앱으로 별도 검증한다.
- 변경 후 관련 검증을 수행한다. 기본 검증 명령은 `pnpm lint`, `pnpm typecheck`, `pnpm test`다.
