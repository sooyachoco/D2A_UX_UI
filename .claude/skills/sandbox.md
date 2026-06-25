---
name: sandbox
description: (보일러플레이트 유지보수자 전용) 보일러플레이트 로컬 브랜치를 골라 실제 파생 프로젝트 샌드박스를 만들어 검증. "샌드박스 만들어줘", "브랜치 검증 샌드박스", "파생 프로젝트 검증" 요청 시 사용.
---

# Sandbox — 로컬 브랜치 파생 프로젝트 검증 샌드박스

> ⚠️ **보일러플레이트 유지보수자 전용 스킬.** 파생 프로젝트에는 배포되지 않는다
> (clean-fork.sh / d2a-installer 가 설치 시 strip). **보일러플레이트 repo 안에서만** 동작한다.

보일러플레이트의 **로컬 브랜치(미push 포함)** 를 골라, **로컬 clone** 으로 실제 파생 프로젝트
샌드박스를 한 번에 만든다. 검증은 사람이 새 Claude Code 세션에서 진행한다.

> 원격(GitLab)이 아니라 **로컬 repo 에서 clone** 하므로 push 하지 않은 브랜치도 검증할 수 있다.
> (d2a-installer 채팅 흐름은 원격 API 기준이라 미push 브랜치는 목록에 안 뜨고 설치도 안 됨 — 그래서 이 툴이 필요하다.)

---

## 동작

`scripts/sandbox.sh` 래퍼를 호출한다:

| 사용자 의도 | 실행 |
|---|---|
| "샌드박스 만들어줘" (브랜치 미지정) | `bash scripts/sandbox.sh new` → 로컬 브랜치 목록에서 번호 선택 |
| "feat/X 샌드박스 만들어줘" | `bash scripts/sandbox.sh new feat/X` |
| "샌드박스 목록" | `bash scripts/sandbox.sh ls` |
| "샌드박스 폐기 <이름>" | `bash scripts/sandbox.sh rm <이름>` |

`new` 가 자동으로 하는 일 (이전 수동 방법 A 전체를 한 명령으로):
1. 보일러플레이트 **로컬 브랜치** 선택 (인자 또는 목록)
2. `git clone --branch <브랜치> "$BP_ROOT" <샌드박스>` — **로컬 경로 clone**(미push OK)
3. `clean-fork.sh` 실행 (template 추출 + 전용파일 제거 + sandbox 도구 strip + 커밋)
4. MCP 하네스 빌드 (best-effort)
5. `code <샌드박스>` 로 VS Code 새 창 오픈

- 샌드박스 루트: `~/d2a-sandboxes/` (환경변수 `D2A_SANDBOX_ROOT` 로 변경 가능)
- 디렉터리명: `<브랜치slug>-NN` (예: `feat-my-change-01`)

---

## `new` 이후 — 반드시 사용자에게 전달할 안내

`new` 는 샌드박스를 **설치 완료 상태**까지 만든다. 검증 채팅은 **새 창의 새 Claude Code 세션**에서 사람이 직접:

1. 열린 새 창에서 Claude Code 세션을 새로 시작
2. `boilerplate-setup 실행해줘`
3. 이후 `create-spec 실행해줘` → `run-phase 1 해줘` 로 변경 동작 검증

> ⚠️ **현재 세션에서 샌드박스 세션을 대신 구동할 수 없다** — 새 워크스페이스·새 세션이
> 필요하다. 이 스킬은 샌드박스 생성·안내까지만 담당한다.

---

## 검증 사이클

```
(보일러플레이트 로컬 브랜치 수정 → 커밋)     ← 로컬 clone 은 커밋 상태만 반영
sandbox.sh new feat/my-change               ← clone + clean-fork + 빌드 + 오픈
   → 새 창에서 boilerplate-setup … 으로 검증
(문제 발견 → 브랜치 수정 → 커밋)
sandbox.sh new feat/my-change               ← 새 샌드박스(-02)로 오염 없는 재검증
sandbox.sh rm feat-my-change-01             ← 끝난 샌드박스 폐기
```
