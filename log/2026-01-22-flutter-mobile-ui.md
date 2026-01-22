# Flutter 모바일 UI 개선 작업

## 날짜
2026-01-22

## 작업 내용

### 1. 모바일 스와이프 네비게이션 구현
- `Listener` 위젯으로 마우스/터치 드래그 감지
- `onPointerDown`, `onPointerMove`, `onPointerUp` 이벤트 처리
- 드래그 중 페이지가 실시간으로 따라오도록 구현
- 20% 이상 드래그 시 페이지 전환, 미만 시 스냅백

### 2. 모바일 상단바 개선
- 데스크탑과 동일한 연결 상태 표시 ("Connected" / "Disconnected" 배지)
- 연결된 파일런 아이콘 표시
- 데스크 미선택 시에도 뒤로가기 버튼 표시

### 3. 모바일 데스크 추가 기능
- 파일런 헤더에 `+` 버튼 추가
- `NewDeskDialog` 연동

### 4. 데스크 설정 기능 (이전 세션에서 시작)
- 선택된 데스크에 설정 버튼 (⋮) 표시
- `DeskSettingsDialog` - 이름 변경, 삭제 기능
- 컴팩트한 SimpleDialog 스타일

### 5. Flutter 웹 서버 설정
- `-d web-server --web-port=8080` 옵션으로 브라우저 없이 서버만 실행
- `-d chrome`은 새 Chrome 창을 열고, 창이 닫히면 서버도 종료됨

## 수정된 파일
- `lib/ui/layouts/mobile_layout.dart` - 스와이프, 상단바, 데스크 추가
- `lib/ui/widgets/sidebar/desk_settings_dialog.dart` - 설정 다이얼로그
- `lib/ui/widgets/sidebar/desk_list_item.dart` - 설정 버튼
- `lib/app.dart` - scrollBehavior 설정 (마우스 드래그 지원)

## 미완료/이슈
- "안녕이 두번 찍혀" - 원인 미파악, 다음 세션에서 확인 필요
- 부드러운 스와이프 애니메이션 추가 검토 필요

## 서버 실행 방법
```bash
cd C:\WorkSpace\estelle\estelle-app
C:\flutter\bin\flutter.bat run -d web-server --web-port=8080
```

브라우저에서 `http://localhost:8080/?mobile=true` 접속
