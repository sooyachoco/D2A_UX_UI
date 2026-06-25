# Integration Readiness Certificate

> `/collect-prerequisites` 스킬이 모든 Smoke Test 통과 후 자동 생성합니다.
> `/run-phase` 스킬은 이 파일의 판정이 ✅ 상태인지 확인 후 실행합니다.

**발급일**: {YYYY-MM-DD HH:MM}
**프로젝트**: {프로젝트명}
**발급 방식**: collect-prerequisites 자동 검증

---

## Smoke Test 결과

| 시스템 | 테스트 명령 | 결과 | 확인 일시 |
|---|---|---|---|
| {시스템 1} | `{curl/ping/psql 명령}` | ✅ / ❌ | {HH:MM} |
| {시스템 2} | `{명령}` | ✅ / ❌ | {HH:MM} |

---

## 환경변수 상태

| 변수명 | 상태 | 비고 |
|---|---|---|
| {ENV_VAR_1} | ✅ 설정됨 | |
| {ENV_VAR_2} | ✅ 설정됨 | |

---

## 판정: {✅ AUTONOMOUS ZONE 진입 가능 / ❌ 미완료 항목 있음}

> 판정이 ✅ 가 아닌 경우 `run-phase` 스킬이 실행을 거부합니다.
> 채팅창에 `"collect-prerequisites 실행해줘"`라고 입력하여 미완료 항목을 해결하세요.
