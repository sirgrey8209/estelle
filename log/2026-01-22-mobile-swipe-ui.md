# 모바일 스와이프 UI 마이그레이션

## 상태: WIP (Relay 연결 문제 해결 필요)

## 릴리스
- **버전**: v1.0.m1
- **GitHub**: https://github.com/sirgrey8209/estelle/releases/tag/v1.0.m1
- **커밋**: 101eff0

## 목표
데스크톱 버전의 UI/기능을 모바일로 마이그레이션하되, 데스크 섹션과 채팅 섹션을 좌우 스와이프로 전환

## 완료된 작업

### UI 구현
- HorizontalPager로 2페이지 스와이프 UI 구현
- DeskListPage: Pylon별 데스크 목록
- ChatPage: Claude 대화 화면 (메시지, 권한, 질문, 도구호출)
- 페이지 인디케이터 (상단 점 2개)

### 파일 변경
- `estelle-mobile/app/build.gradle.kts` - foundation 의존성 추가
- `estelle-mobile/app/src/main/java/com/nexus/android/MainActivity.kt` - 전면 재작성
- `estelle-mobile/app/src/main/java/com/nexus/android/MainViewModel.kt` - 전면 재작성
- `estelle-mobile/version.properties` - v1.0.m1로 업데이트

## 알려진 문제
- **Relay 연결 안 됨**: MainViewModel과 RelayClient 간의 데이터 흐름/구조 문제로 추정
- 데스크 목록이 표시되지 않음

## 다음 작업
- Relay 연결 구조 파악 및 수정 필요
- `wip/mobile-relay-fix.md` 참조

---
작성일: 2026-01-22
