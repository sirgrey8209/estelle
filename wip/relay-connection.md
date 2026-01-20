# WIP: Relay 연결 문제

## 상태
진행 중

## 문제
- 회사 DNS에서 `estelle-relay.fly.dev`의 IPv4 레코드가 전파되지 않음
- nslookup은 되지만 curl 연결 실패

## 임시 해결
hosts 파일에 수동 추가:
```
66.241.125.22 estelle-relay.fly.dev
```

## 확인 필요
- [ ] DNS 전파 완료 후 hosts 파일 엔트리 제거
- [ ] Pylon → Relay 연결 테스트
- [ ] Desktop 앱에서 Relay 상태 ON 확인
