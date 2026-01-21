# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 대화 스타일

- 항상 경어체(존댓말)로 답변할 것

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
     