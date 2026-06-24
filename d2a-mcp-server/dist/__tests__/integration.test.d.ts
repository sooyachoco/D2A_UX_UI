/**
 * 통합 테스트: getNextTask → submitTask 전체 Phase 실행 흐름 검증
 *
 * 단위 테스트(phase-runner.test.ts)는 각 도구를 독립적으로 검증한다.
 * 이 파일은 실제 Phase 실행 시나리오를 end-to-end로 검증한다:
 *   1. 정상 흐름: 다중 태스크 Phase 완료까지 순차 실행
 *   2. 빌드 실패 에스컬레이션: retry → rollback → state.json blocker 기록
 *   3. deps 체인: A→B→C 순서 강제 검증
 *   4. 혼합 done 타입: file:, cmd:, contains: 복합 사용
 */
export {};
//# sourceMappingURL=integration.test.d.ts.map