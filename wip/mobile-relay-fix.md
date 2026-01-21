# 모바일 Relay 연결 수정

## 상태: TODO

## 문제
v1.0.m1에서 스와이프 UI는 구현되었으나 Relay 연결이 안 됨
- 데스크 목록이 표시되지 않음
- Pylon 연결 구조 확인 필요

## 분석 필요 사항

### 1. 현재 구조 파악
- [ ] RelayClient.kt의 메시지 수신 흐름
- [ ] MainViewModel.kt에서 RelayClient 이벤트 구독 방식
- [ ] 데스크톱 App.jsx와 비교하여 차이점 확인

### 2. 의심 포인트
- MainViewModel에서 RelayClient의 desks/messages를 collect하는 부분
- Relay → Pylon → Desk 구조가 제대로 반영되지 않았을 가능성
- deviceId vs deskId 혼동 가능성

### 3. 확인할 파일
- `estelle-mobile/app/src/main/java/com/nexus/android/RelayClient.kt`
- `estelle-mobile/app/src/main/java/com/nexus/android/MainViewModel.kt`
- `estelle-relay/src/index.ts` (릴레이 서버 프로토콜)
- `estelle-desktop/src/App.jsx` (참조 구현)

## 해결 방안
1. 로그 추가하여 실제 수신되는 메시지 확인
2. RelayClient → MainViewModel 데이터 흐름 디버깅
3. 필요시 구조 수정

---
작성일: 2026-01-22
