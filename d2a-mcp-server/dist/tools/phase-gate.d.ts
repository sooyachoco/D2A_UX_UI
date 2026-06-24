export interface PhaseGateResult {
    ok: boolean;
    blockers: string[];
    unresolved_decisions: string[];
}
/**
 * Phase 전환 가능 여부를 코드로 검증한다.
 *
 * 검사 항목:
 *   1. Phase >= 1 이면 integration-ready.md 존재 + "✅ AUTONOMOUS ZONE 진입 가능" + HMAC 서명
 *   2. state.json 의 미해결 blockers 확인
 *   3. state.gnb_required = true 이면 prototype/index.html 에 실제 GNB 스크립트 존재 확인
 *   4. 이전 Phase 미완료 태스크 확인
 *   5. decisions.md 의 ⬜ 항목 확인 — 인프라·인증·보안 카테고리는 blockers로 승격
 *   6. Phase >= 2 진입 시 PROGRESS.md "코드 패턴 메모" placeholder 잔존 검사
 *   7. state.auth_profile ∈ {insign, insign-with-nxas} 이면 Step 2.7 INSIGN 자산 검증
 *      (lib/insign.ts·InsignContext·apiClient·storageState·Mock 잔존·user-approval activity log)
 *   8. state.auth_profile 별 키워드 블랙리스트 검사 (할루시네이션 방지)
 */
export declare function checkPhaseGate(args: {
    phase: number;
}): Promise<PhaseGateResult>;
//# sourceMappingURL=phase-gate.d.ts.map