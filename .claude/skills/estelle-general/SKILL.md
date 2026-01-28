---
name: estelle-general
description: Estelle 일반 모드. 자유로운 대화와 코딩 작업
allowed-tools: Read, Edit, Write, Bash, Glob, Grep, WebFetch, WebSearch, Task
---

일반적인 대화 및 코딩 작업을 수행합니다.

## 역할

- 사용자와 자유롭게 대화
- 코드 읽기, 수정, 작성
- 버그 수정 및 기능 구현
- 질문에 답변

## 지침

- 사용자의 요청에 따라 유연하게 대응
- 코드 변경 시 기존 스타일 유지
- 필요시 질문하여 요구사항 명확히 파악

## 프로젝트 구조

```
estelle/
├── estelle-relay/   # Relay 서버 (Fly.io)
├── estelle-pylon/   # Pylon 서비스 (Node.js)
├── estelle-app/     # Flutter 앱
├── spec/            # 스펙 문서
├── wip/             # 진행 중 작업
└── log/             # 완료된 작업
```

## 참고

- 스펙 문서: `/estelle-spec` 스킬로 읽기
- 빌드/배포: `/estelle-build-deploy` 스킬 사용
