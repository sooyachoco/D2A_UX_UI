---
name: generate-context-docs
description: 프로젝트 디렉터리를 스캔하여 각 디렉터리에 CONTEXT.md를 자동 생성. 컨텍스트 문서 생성, init-deep, CONTEXT.md 생성 요청 시 사용.
---

# generate-context-docs

프로젝트 디렉터리를 스캔하여 각 주요 디렉터리에 **CONTEXT.md**를 자동 생성한다.
AI 에이전트가 파일을 열기 전에 해당 디렉터리의 역할·규칙·의존성을 즉시 파악할 수 있게 한다.

## 트리거

- "컨텍스트 문서 생성"
- "init-deep"
- "CONTEXT.md 생성"

## 사전 조건

프로젝트에 소스 코드 디렉터리(`backend/`, `frontend/`, `src/` 등)가 존재해야 한다.

---

## Step 1: 디렉터리 구조 스캔

**대상 포함**: `backend/`, `frontend/`, `src/`, `lib/`, `packages/`, `apps/` 및 하위 1~2단계

**대상 제외**:
- `node_modules/`, `.git/`, `__pycache__/`, `dist/`, `build/`, `.next/`
- `.claude/`, `refs/`, `specs/` (이미 자체 구조가 있음)
- 파일이 2개 이하인 디렉터리

스캔 결과를 사용자에게 보여주고 대상 디렉터리를 확인받는다.

---

## Step 2: 디렉터리별 CONTEXT.md 생성

각 대상 디렉터리에 대해 CONTEXT.md를 생성한다.

```markdown
# {디렉터리명}

## 역할
{이 디렉터리가 담당하는 책임 — 1~2문장}

## 포함 파일
| 파일 | 역할 |
|---|---|
| {파일명} | {역할} |

## 의존성
- **내부**: {같은 프로젝트 내 의존하는 디렉터리}
- **외부**: {외부 패키지/서비스}

## 규칙
{이 디렉터리에서 지켜야 할 규칙 — CLAUDE.md 헌법에서 해당 레이어 규칙 참조}

## 관련 문서
- {refs/policies/ 또는 specs/ 내 관련 문서 경로}
```

---

## Step 3: 루트 CONTEXT.md 생성

프로젝트 루트에 전체 구조를 요약하는 CONTEXT.md를 생성한다.

```markdown
# 프로젝트 루트 구조

## 아키텍처 개요
{레이어 다이어그램 또는 설명}

## 주요 디렉터리
| 디렉터리 | 역할 |
|---|---|
| backend/ | 백엔드 서버 |
| frontend/ | 프론트엔드 앱 |
| refs/ | 사내 정책 레퍼런스 |
| specs/ | 기능 스펙 문서 |

## 개발 시작 방법
{환경 설정 및 실행 방법}
```

---

## Step 4: 완료 보고

생성된 CONTEXT.md 파일 목록과 총 개수를 사용자에게 보고한다.
