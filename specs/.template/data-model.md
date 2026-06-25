# 데이터 모델

> spec.md + plan.md 기반 DB 설계입니다.

## ERD 요약

{주요 엔티티 관계 설명}

## 테이블 정의

### {테이블명}

| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| id | UUID | PK | |
| created_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | |
| updated_at | TIMESTAMP | NOT NULL | |

### 인덱스

| 테이블 | 인덱스 | 컬럼 | 용도 |
|---|---|---|---|
| {테이블} | {인덱스명} | {컬럼} | {조회 패턴} |
