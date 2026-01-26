# 모바일 UX 개선 작업

## 완료된 작업

### 1. 모바일 레이아웃 개편 (mobile_layout.dart)
- 최상단 바: Estelle / 접속상태 / 설정버튼
- 서브 헤더: 워크스페이스 or 채팅(뒤로가기+대화명+메뉴)
- 스와이프: 2페이지만 (워크스페이스, 채팅). 설정은 별도 화면
- 스와이프 임계값: deadZone 0.1, maxZone 0.4

### 2. 대화 선택 시 자동 탭 전환
- ref.listen을 build 메서드로 이동

### 3. 디바이스 ID 체계 변경
- Device 1 = 회사, Device 2 = 집
- Selene/Stella 이름 제거

### 4. Pylon 아이콘 미표시 해결
- registered 응답 처리 추가
- 앱에서 deviceId로 기본 아이콘 표시

### 5. 채팅 헤더 UI 변경
- 대화명 + 상태 닷 표시
- 워크스페이스 경로 표시

### 6. 설정 화면 복구
- PermissionModeSection 추가

### 7. Android URL 열기 해결
- AndroidManifest.xml에 VIEW intent 추가

### 8. 채팅 메뉴에 버그 리포트 추가
- PopupMenuDivider + bug_report 메뉴 항목 추가
- _handleAction에 BugReportDialog.show(context) 호출

## 배포 필요
- estelle-app 빌드
- estelle-pylon 재시작
- estelle-relay 재배포 (선택)
