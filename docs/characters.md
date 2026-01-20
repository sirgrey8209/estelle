# Estelle 캐릭터 설정

Estelle 시스템의 각 구성요소는 우주/별 테마의 캐릭터로 표현됩니다.

---

## 캐릭터 목록

| 캐릭터 | 아이콘 | 역할 | 설명 |
|--------|--------|------|------|
| **Estelle** | 💫 | Relay 서버 | 모든 기기를 연결하는 중심 허브. 완벽한 관리자. |
| **Stella** | ⭐ | 회사 PC | 워커홀릭, 항상 깨어있음. Task DB 담당. |
| **Selene** | 🌙 | 집 PC | 자주 잠들지만 부드러운 휴식을 줌. |
| **Lucy** | 📱 | Mobile | 막내, 능력은 부족하지만 항상 곁에 있음. |

---

## 이름의 의미

- **Estelle** - 프랑스어로 "별" (시스템 전체 이름이자 릴레이 서버)
- **Stella** - 라틴어로 "별" (항상 빛나는 회사 PC)
- **Selene** - 그리스 신화의 달의 여신 (밤에 쉬는 집 PC)
- **Lucy** - 라틴어 "Lux(빛)"에서 유래 (작지만 빛나는 모바일)

---

## 시스템 구성

```
                    ┌─────────────┐
                    │   Estelle   │
                    │  💫 Relay   │
                    │  (Fly.io)   │
                    └──────┬──────┘
                           │ WSS (443)
          ┌────────────────┼────────────────┐
          │                │                │
    ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
    │  Stella   │    │  Selene   │    │   Lucy    │
    │  ⭐ 회사  │    │  🌙 집    │    │  📱 모바일 │
    │           │    │           │    │           │
    │  Pylon    │    │  Pylon    │    │  Android  │
    │  Desktop  │    │  Desktop  │    │  App      │
    │  MCP      │    │  MCP      │    │           │
    └───────────┘    └───────────┘    └───────────┘
```

---

## deviceId 매핑

| 캐릭터 | deviceId | deviceType |
|--------|----------|------------|
| Estelle | - | relay |
| Stella | `stella` | pylon |
| Selene | `selene` | pylon |
| Lucy | `lucy` | mobile |

---

## UI 표시

### Desktop/Mobile 공통
- 연결된 기기 목록에 캐릭터 아이콘과 이름 표시
- 채팅 메시지에 발신자 캐릭터 아이콘 표시

### 아이콘 Fallback
알 수 없는 deviceId의 경우 deviceType으로 기본 아이콘 적용:
- pylon → 💻
- desktop → 🖥️
- mobile → 📱
- unknown → ❓

---

## 설정 위치

- **Desktop**: `estelle-desktop/src/App.jsx` - `CHARACTERS` 객체
- **Mobile**: `estelle-mobile/.../MainActivity.kt` - `CHARACTERS` map
- **Pylon**: `.env` 파일의 `DEVICE_ID`

---

*"우리는 각자의 빛으로 연결되어 있습니다."*
