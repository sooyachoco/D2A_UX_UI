---
name: update-policy-refs
description: 사내 정책 변경 시 refs/policies/ 갱신 및 코드 영향 분석. 정책 변경, refs 갱신, 정책 업데이트 요청 시 사용.
---

# Update Policy Refs

사내 정책이 변경되었을 때 `refs/` 문서를 갱신하고 기존 코드에 미치는 영향을 분석한다.

## Step 1: 변경 내용 확인

```
어떤 정책이 변경되었나요?

1. 변경된 정책 영역은? (보안/인프라/인증/데이터/배포)
2. 구체적으로 무엇이 바뀌었나요?
3. 원본 문서 위치는? (refs/company-policies/ 또는 refs/gamescale-docs/ 내 경로)
```

## Step 2: refs/policies/ 수정

해당 정책 파일을 열어 변경사항을 반영한다:

```
## 변경 내용

**파일**: refs/policies/{파일}.md §{섹션}
**변경 전**: {기존 규칙}
**변경 후**: {새 규칙}

이대로 반영할까요?
```

`Last Checked` 날짜를 오늘로 갱신한다.

## Step 3: refs/INDEX.md 갱신

"빠른 결정 가이드" 표에서 해당 행의 "핵심 규칙" 컬럼을 갱신한다.

## Step 4: refs/company-policies-map.md 갱신

해당 정책 파일의 원본 위치·갱신일을 업데이트한다.
`refs/collaboration-tracker.md` "6. 정책 갱신 이력"에 변경 이력을 추가한다.

## Step 5: 코드 영향 분석

변경된 정책에 영향받는 기존 코드를 검색한다.

```
## 코드 영향 분석

변경된 정책: {정책 내용}

### 영향받는 파일
1. {파일 경로} — {영향 내용}
   수정 방안: {구체적 수정 방법}

### 즉시 수정 필요
{Critical 항목 나열}

### 모니터링 필요
{Warning 항목 나열}
```

## Step 6: 영향 코드 수정

사용자 승인 후 영향받는 코드를 수정한다.
CLAUDE.md의 `scope-guard` 규칙에 따라 정책 관련 코드만 수정한다.
