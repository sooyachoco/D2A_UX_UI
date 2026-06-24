/**
 * prerequisites.md의 각 ⬜ 차단 항목이 정책 문서로 뒷받침되는지 검증한다.
 *
 * 케이스 배경: docs/case-studies/step27-validation-gap.md 4.7 장치 1.
 * INSIGN 프로젝트에서 메인 에이전트가 정책 문서를 읽지 않고 OAuth 표준
 * 패턴(client_secret·redirect_uri 등)을 prerequisites.md에 ⬜로 추가하는
 * 할루시네이션이 발견되었다. 이 도구는 다음을 강제한다:
 *
 *   1. ⬜ 마커가 붙은 행마다 `근거:` 필드 또는 같은 행/직후 행의
 *      `근거: refs/policies/{file}.md` 패턴 존재 확인.
 *   2. 정책 파일 인용 시 → 해당 파일에 항목 키워드가 grep으로 매치되는지 확인.
 *      매치 0건 시 "근거 부적합" blocker.
 *   3. `근거: 사용자 입력` / `근거: 운영 정책` 같은 명시적 비-정책 출처는 통과.
 *
 * 호출 시점:
 *   - /collect-prerequisites 종료 시 (Phase 0.5 완료 전)
 *   - check_phase_gate(phase=1)에서 보조 호출 (옵션)
 */
export interface GroundedResult {
    ok: boolean;
    total_blocked_items: number;
    ungrounded: Array<{
        line: number;
        text: string;
        reason: string;
    }>;
}
export declare function checkPrerequisitesGrounded(): Promise<GroundedResult>;
//# sourceMappingURL=prerequisites-grounded.d.ts.map