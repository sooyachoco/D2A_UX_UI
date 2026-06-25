# EXTERNAL_BENCHMARKS — 외부 스트리밍 벤치마크 (3자 데이터)

> ⚠️ **등급: 벤치마크 전용 (🔵 외부 참고)**. 모두 YouTube/Twitch 등 **3자 플랫폼 일반 시청 패턴**이며
> NEXON Live 1차 데이터가 아니다. 페르소나 **검증 근거로 쓰지 않는다** — 가설 점검·설계 사전(prior)·정량 비교용.
> NEXON Live 1차 데이터는 [USER_RESEARCH.md](USER_RESEARCH.md) "실증 데이터 출처" S5(쇼케이스 설문) 참조.

**최종 갱신**: 2026-06-25

---

## 1. MCP 연결 가능 여부 (체크 결과)

| 경로 | MCP 네이티브 | 결론 |
|---|---|---|
| MCP 레지스트리 (streaming/audience/analytics 키워드) | ❌ 0건 | 즉시 연결 가능한 커넥터 없음 (2026-06 기준) |
| 공개 데이터셋 (YTLive·Twitch) | ❌ | 다운로드/WebFetch로 가져오거나 import 래퍼 필요 |
| Streams Charts API (Twitch·YouTube·Kick·Rumble) | ❌ (REST) | 커스텀 MCP 래퍼 구현 필요 — API 키·비용 발생 |

→ **외부는 "바로 꽂기" 불가.** 라이브 연동은 별도 개발(아래 4번) 필요.

## 2. 외부 데이터 소스

| 소스 | 규모/내용 | 유형 | 링크 |
|---|---|---|---|
| YTLive Dataset | 12,156개 라이브, 50.7만 레코드, 5분 간격 동접·방송 길이 | 공개 데이터셋 | [arXiv](https://arxiv.org/html/2510.24769v1) |
| Twitch Consumption Dataset | 로그인 유저 43일 시청 행태 (개별 시청 습관 최초 공개) | 공개 데이터셋 | [UCSD](https://cseweb.ucsd.edu/~jmcauley/pdfs/recsys21b.pdf) |
| Streams Charts API | Twitch·YouTube·Kick·Rumble 실시간 지표 | 상용 API | [streamscharts.com/api](https://streamscharts.com/api) |

## 3. 벤치마크 인사이트 (가설 점검용 — NEXON Live 직접 적용 금지)

- 주말·오후 시간대 시청자 수가 높고 안정적 → NEXON Live 편성·트래킹 비교 기준
- 짧은 방송이 더 크고 일관된 시청자 확보, 긴 방송은 느리게 성장·변동 큼 → 방송 길이 설계 참고
- (출처: YTLive 분석)

## 4. 라이브 MCP 연동 시 필요 요건 (미완 — 의사결정 대기)

Streams Charts API 래퍼 또는 YTLive import를 MCP로 붙이려면:

1. **API 키·비용 승인** (Streams Charts 유료) — 카테고리 A(외부 서비스) 결정 필요
2. **연동 방식 선택**: (a) 커스텀 MCP 서버(`tools/`에 추가) (b) 단순 데이터셋 import 후 정적 분석
3. **개인정보/약관 검토** — 3자 플랫폼 데이터 사용 범위
4. **목적 정의** — 벤치마크 비교만? 아니면 상시 트래킹?

> 위 1~4가 정해지기 전까지 외부 라이브 연동은 **미착수**. 본 문서는 벤치마크 레퍼런스로만 유효.
