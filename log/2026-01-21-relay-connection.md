# Relay 연결 문제 해결

## 상태
완료 (2026-01-21)

## 문제
- 회사 DNS에서 `estelle-relay.fly.dev`의 IPv4 레코드가 전파되지 않음
- nslookup은 되지만 curl 연결 실패

## 임시 해결 (적용했었음)
hosts 파일에 수동 추가:
```
66.241.125.22 estelle-relay.fly.dev
```

## 해결
- [x] DNS 전파 완료 확인 (IPv4: 66.241.125.22, IPv6: 2a09:8280:1::c6:4aca:0)
- [x] hosts 파일 엔트리 제거 (주석 처리)
- [x] DNS 캐시 flush (`ipconfig /flushdns`)
- [x] Relay 연결 테스트 성공 (HTTP 426 - WebSocket 정상)

## 결론
DNS 전파 완료로 hosts 파일 없이 정상 연결됨.
