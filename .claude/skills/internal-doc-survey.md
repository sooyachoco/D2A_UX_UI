---
name: internal-doc-survey
description: 사내 정책 문서에서 정책 정보를 수집하여 refs/policies/에 반영. 사내 정책 조사, refs 채우기, 보안/인프라/인증 정책 검색 요청 시 사용. CLAUDE.md check-policy-refs 규칙의 래더 상세 절차도 포함.
---

# Internal Document Survey

사내 정책 문서(`refs/company-policies/`, `refs/gamescale-docs/`)에서 정책 정보를 검색하여 `refs/` 구조에 반영한다.

## 정책 조회 래더 (CLAUDE.md check-policy-refs 규칙에서 참조)

기술 결정이 필요할 때 아래 순서로 정보를 찾는다:

**1단계**: `refs/INDEX.md`의 "빠른 결정 가이드" 표를 확인한다.

**2단계**: INDEX만으로 부족하면 `refs/policies/` 해당 파일을 읽는다.

**3단계**: `refs/policies/`에 값이 비어있으면 `refs/company-policies-map.md`에서
해당 항목을 커버하는 사내 정책 문서 경로를 찾아 `refs/company-policies/{경로}`를 읽는다.

**4단계**: 사내 정책 문서에도 없으면 `refs/gamescale-docs-index.md`의 키워드 라우팅으로
`refs/gamescale-docs/public/docs/ko/{경로}` 파일을 읽는다.

**5단계**: 위 1~4단계에서 정보를 찾지 못하면 **업계 표준/보편적 관행**을 적용한다.
적용한 내용을 `refs/policies/`에 기록하고 상태를 🤖(AI 제안)으로 표시한다.
`refs/collaboration-tracker.md` "4. 개발 과정에서 발견된 항목"에도 기록한다.

보편적 관행 기준:
- 클라우드: AWS (ap-northeast-2)
- 보안: OWASP Top 10, TLS 1.2+, HTTPS 필수
- 개인정보: 개인정보보호법 기준
- 배포: 컨테이너 기반, CI/CD 자동화

---

## 워크플로

### Step 1: 검색 대상 확인

사용자에게 질문:
```
어떤 정책 정보를 찾을까요?
예: "SSL 인증서 정책", "SSO 연동 가이드", "보안 진단 절차"
```

### Step 2: 로컬 문서 검색

정책 조회 래더의 1~4단계를 순서대로 실행한다.

### Step 3: refs/policies/ 갱신

검색 결과를 해당 정책 파일에 반영한다:

```markdown
## {섹션명}
**상태**: 🟢 사내 문서 / 🤖 AI 제안
**Last Checked**: {날짜}

{정책 내용}
```

### Step 4: refs/INDEX.md 갱신

"빠른 결정 가이드" 표에 새로 추가된 정책 항목을 반영한다.

### Step 5: collaboration-tracker.md 갱신

새로 수집한 정책을 `refs/collaboration-tracker.md`에 기록한다.

