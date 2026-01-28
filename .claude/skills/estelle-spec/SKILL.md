---
name: estelle-spec
description: Estelle 프로젝트 스펙 읽기. 새 세션 시작 시 프로젝트 파악용
allowed-tools: Read, Glob
---

Estelle 프로젝트의 스펙 문서를 순서대로 읽어 프로젝트를 파악합니다.

## 읽기 순서

1. `spec/overview.md` - 프로젝트 개요, 시스템 구조
2. `spec/architecture-decisions.md` - 설계 의도와 결정 이유
3. `spec/entrypoints.md` - 코드 진입점과 컴포넌트 계층
4. `spec/logs.md` - 로그 파일 위치와 확인 방법

## 실행

모든 스펙 파일을 순서대로 읽고, 핵심 내용을 요약해서 보여주세요.

```
spec/overview.md
spec/architecture-decisions.md
spec/entrypoints.md
spec/logs.md
```

## 읽은 후

간단히 요약:
- 시스템 구조 (Relay, Pylon, App)
- 핵심 설계 원칙
- 주요 진입점
