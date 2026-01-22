# 모바일 Relay 연결 수정 → Desktop 통합

## 상태: MIGRATED → estelle-app

> ⚠️ **이 문서는 더 이상 유효하지 않습니다.**
> estelle-mobile과 estelle-desktop은 estelle-app로 통합되었습니다.
> Relay 통신 로직은 Flutter의 `relay_service.dart`에서 구현됨.
> Flutter 마이그레이션 내용은 `log/2026-01-22-flutter-migration.md` 참조

---

## (아카이브) 이전 상태: TESTING

## 문제
v1.0.m1에서 스와이프 UI는 구현되었으나 Relay 연결이 안 됨
- 데스크 목록이 표시되지 않음
- Pylon 연결 구조 확인 필요

## 원인 분석

### Desktop vs Mobile 차이 (기존)
- **Desktop**: Pylon(`localhost:9000`)에 직접 연결 → Pylon이 `desk_list_result` 자동 브로드캐스트
- **Mobile**: Relay(`wss://estelle-relay.fly.dev`)에 연결 → Relay는 순수 라우터라서 `desk_list` 요청 필요

### 근본 원인
`MainViewModel.kt`의 `init` 블록에서 인증 성공 후 `requestDeskList()`를 호출하지 않았음

## 해결 (Mobile) - DONE

`MainViewModel.kt`에 인증 성공 시 자동으로 데스크 목록을 요청하는 코드 추가:

```kotlin
// 인증 성공 시 데스크 목록 요청
viewModelScope.launch {
    relayClient.isAuthenticated.collect { authenticated ->
        if (authenticated) {
            relayClient.requestDeskList()
        }
    }
}
```

## 추가 결정: Desktop도 Relay 경유로 통일

### 배경
- 집 컴퓨터에서 집/회사 양쪽 데스크 조작 필요
- Desktop이 로컬 Pylon에만 연결하면 원격 Pylon 데스크 접근 불가

### 검토한 옵션들

1. **이중 연결 (로컬 Pylon + Relay)**
   - 장점: Relay 장애 시 로컬 작업 가능
   - 단점: 코드 복잡, 중복 메시지 처리 필요

2. **Relay만 사용 (선택)**
   - 장점: 코드 단순, 라우팅 통일
   - 단점: Relay 장애 시 로컬도 불가

### 결정
- **Relay만 사용**하는 것으로 단순화
- 이유: 대단히 반응성을 요하는 게 아님, 코드 단순화 우선
- 향후: 로컬 통신 모드는 나중에 필요 시 별도 구현

## 수정 완료 (Desktop) - DONE

### 변경 사항
1. `connectToPylon()` 함수 제거 → `connectToRelay()`만 사용
2. `wsRef`: 로컬 Pylon용 → Relay용으로 변경
3. `relayWsRef`, `localPylonDeviceIdRef`, `relayAuthenticatedRef` 제거
4. `isAuthenticated` ref 추가 (인증 상태 추적)
5. `send()` 함수: Relay 전용으로 단순화
6. `handleMessage()`: source 파라미터 제거
7. `connected` 상태 하나로 통합 (Relay 인증 성공 시 true)
8. 헤더 상태 표시 단순화 (Disconnected/Connected)

## Pylon 수정 - DONE

### 변경 사항
1. `desk_list` 요청에 `from` 정보가 있으면 요청자에게 직접 응답
2. `sendDeskListTo(target)` 함수 추가 - 특정 클라이언트에게 `to` 필드로 응답

### 기존 유지
- `broadcastDeskList()`는 `broadcast: 'clients'`로 모든 클라이언트에 브로드캐스트

## Relay 수정 - DONE

### 변경 사항
1. `getDeviceInfo()` 개선 - 동적 디바이스 (100 이상)에 대해 `Client {id}` 이름과 📱 아이콘 사용

### 기존 유지
- `broadcast: 'pylons'` → 모든 Pylon에 브로드캐스트
- `broadcast: 'clients'` → Pylon 제외 모든 클라이언트에 브로드캐스트
- `to` 필드 → 특정 대상에게 직접 전달
- `from` 정보 자동 주입

### 메시지 플로우
1. Desktop → `{ type: 'desk_list', broadcast: 'pylons' }`
2. Relay → 모든 Pylon에 브로드캐스트
3. 각 Pylon → `{ type: 'desk_list_result', broadcast: 'clients' }`
4. Relay → 모든 Desktop/Mobile에 브로드캐스트

## 수정된 파일 목록

| 컴포넌트 | 파일 | 변경 내용 |
|---------|------|----------|
| Mobile | `MainViewModel.kt` | 인증 후 `requestDeskList()` 자동 호출 |
| Desktop | `App.jsx` | Relay 전용으로 단순화, 로컬 Pylon 코드 제거 |
| Pylon | `index.js` | `sendDeskListTo()` 추가, `desk_list` 요청자 직접 응답 |
| Relay | `index.js` | `getDeviceInfo()` 동적 디바이스 이름/아이콘 개선 |
| Docs | `architecture.md` | 데스크 목록 조회 플로우 추가 |

## 테스트 필요
- [ ] Mobile: 앱 빌드 후 실제 기기에서 데스크 목록 표시 확인
- [ ] Desktop: Relay 경유로 모든 Pylon 데스크 목록 표시 확인
- [ ] Desktop: 원격 Pylon 데스크 조작 확인
- [ ] Claude 메시지 송수신 확인
- [ ] 권한 요청/응답 확인

---
작성일: 2026-01-22
수정일: 2026-01-22
