# WIP: Desktop 앱 개선

## 상태
진행 중

## 해결해야 할 문제

### 1. 콘솔창 숨기기
- npm start 실행 시 뒤에 cmd 창이 뜸
- 해결 방안: electron-builder로 패키징하거나 start 스크립트 수정

### 2. 작업표시줄 고정 문제
- 작업표시줄에 고정하면 Electron만 실행됨 (Vite 서버 없이)
- 해결 방안:
  - 프로덕션 빌드로 패키징
  - 또는 바로가기 생성 시 npm start 포함

## 다음 단계
- [ ] electron-builder 설정
- [ ] 프로덕션 빌드 테스트
- [ ] 설치 프로그램 생성 검토
