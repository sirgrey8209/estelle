# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 대화 스타일

- 항상 경어체(존댓말)로 답변할 것

## Flutter 클라이언트 (estelle-app)

`estelle-app`는 Desktop과 Mobile을 통합한 단일 앱입니다.

- **UI 작업 시 반드시 Desktop/Mobile 양쪽을 고려할 것**
  - Desktop (>=600px): 사이드바 + 채팅 영역
  - Mobile (<600px): PageView 스와이프 (데스크 목록 ↔ 채팅)
- 반응형 분기: `lib/ui/layouts/responsive_layout.dart`
- 레이아웃 파일:
  - Desktop: `lib/ui/layouts/desktop_layout.dart`
  - Mobile: `lib/ui/layouts/mobile_layout.dart`

### Flutter 개발 테스트
개발 시 테스트는 **web-server 모드**로 진행합니다.

**포그라운드 실행 (Hot Reload 지원):**
```bash
start "" "C:\workspace\estelle\estelle-app\run-dev.bat"
```
- 새 터미널 창에서 실행됨
- `r` 키: Hot Reload (소스 변경 반영)
- `R` 키: Hot Restart (앱 상태 초기화)
- `q` 키: 종료

**백그라운드 실행:**
```bash
powershell -Command "Set-Location C:\workspace\estelle\estelle-app; C:\flutter\bin\flutter.bat run -d web-server --web-port=8080"
```

- Desktop 테스트: `http://localhost:8080/`
- Mobile 테스트: 브라우저 개발자도구에서 모바일 뷰포트로 전환

## Shell 주의사항

- Windows 환경에서 `&&` 명령어 체이닝이 동작하지 않음
- 여러 명령어를 실행할 때는 별도의 Bash 호출로 분리할 것
- `cd /d C:\path` 형식도 동작하지 않음 - 작업 디렉토리는 이미 프로젝트 루트로 설정되어 있음
- 절대경로 사용 시 파일 수정이 실패하는 경우가 있음 - 실패 시 상대경로로 재시도할 것

### 문서화
`docs/` : 프로젝트 관련 문서
`wip/` : 현재 진행중인 작업에 대한 계획 및 진행상황
`log/` : 완료된 작업에 대한 로그


```
[작업 시작] → wip/ 에 문서 작성
     ↓
[작업 완료] → log/ 로 이동 (날짜 prefix)
```

- **"하고 있는 일/해야 할 일"** 질문 시 → `wip/` 확인

## 유틸리티 스크립트

### Pylon 재시작
```bash
estelle-pylon/restart.bat
```
또는
```bash
pm2 restart estelle-pylon
```
     