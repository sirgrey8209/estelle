# 다음 작업: Pylon Desk 기능 구현

## 현재 상태
- 데스크 CRUD 기본 구현됨 (생성/삭제/이름변경)
- deskStore.js에서 JSON 파일로 저장
- Claude 세션은 deskId로 구분되지만 workingDir 미적용

## 구현 필요

### 1. workingDir 실제 적용
- [ ] 데스크 생성 시 workingDir 검증
- [ ] Claude 세션 시작 시 workingDir로 cwd 설정
- [ ] 클라이언트에서 workingDir 선택 UI

### 2. Claude 세션 격리
- [ ] 데스크별 독립 세션 관리
- [ ] 세션 상태 (active/idle/error) 추적
- [ ] 세션 재시작/복구 로직

### 3. 데스크 상태 개선
- [ ] 마지막 활동 시간 기록
- [ ] 세션 통계 (토큰 사용량, 대화 수)
- [ ] 데스크별 설정 (권한 모드 등)

## 참고

### 현재 deskStore 구조
```javascript
{
  "deskId": "uuid",
  "name": "작업명",
  "workingDir": "C:\\path\\to\\project",
  "isActive": true,
  "claudeSessionId": "session-uuid",
  "status": "idle"
}
```

### Claude 세션 시작 흐름
```
1. 클라이언트 → Pylon: claude_send { deskId, message }
2. Pylon: claudeManager.sendMessage(deskId, message)
3. claudeManager: 해당 deskId의 Claude 프로세스 시작/재사용
4. Claude SDK → Pylon: 이벤트 스트림
5. Pylon → 클라이언트: claude_event
```

---
*Last updated: 2026-01-22*
