# Pylon deploy.json 조회 방식 변경

## 상태: DONE

## 문제
- Pylon의 `fetchDeployJson()`이 HTTPS로 GitHub Release의 deploy.json을 직접 요청
- **private repository**에서는 인증 없이 접근 불가 (404 반환)
- 결과: `Deployed commit: undefined` → 자동 업데이트 실패

## 해결
`gh` CLI 명령어를 사용하도록 변경 (로컬 인증 활용)

### 변경 전
```javascript
fetchDeployJson() {
  return new Promise((resolve) => {
    const url = `${DEPLOY_JSON_URL}?t=${Date.now()}`;
    https.get(url, { headers: { 'User-Agent': 'Estelle-Pylon' } }, (res) => {
      // redirect 처리 및 JSON 파싱
    });
  });
}
```

### 변경 후
```javascript
fetchDeployJson() {
  return new Promise((resolve) => {
    try {
      const data = execSync(
        'gh release download deploy --repo SirGrey8209/estelle -p "deploy.json" -O -',
        { encoding: 'utf-8', windowsHide: true }
      );
      resolve(JSON.parse(data));
    } catch {
      resolve(null);
    }
  });
}
```

## 변경 파일
- `estelle-pylon/src/index.js` - `fetchDeployJson()` 함수

## 비고
- `gh` CLI가 설치되어 있고 인증된 환경에서만 동작
- public repository로 전환 시 기존 HTTPS 방식도 동작 가능
