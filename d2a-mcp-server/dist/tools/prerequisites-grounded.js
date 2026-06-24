import fs from "fs";
import path from "path";
/** prerequisites.md 후보 경로를 모두 찾는다. */
function findPrerequisitesFiles(cwd) {
    const found = [];
    const direct = path.join(cwd, "prerequisites.md");
    if (fs.existsSync(direct))
        found.push(direct);
    const specsDir = path.join(cwd, "specs");
    if (fs.existsSync(specsDir)) {
        for (const entry of fs.readdirSync(specsDir, { withFileTypes: true })) {
            if (entry.isDirectory() && !entry.name.startsWith(".")) {
                const candidate = path.join(specsDir, entry.name, "prerequisites.md");
                if (fs.existsSync(candidate))
                    found.push(candidate);
            }
        }
    }
    return found;
}
/**
 * ⬜ 차단 항목 한 행에서 `근거:` 패턴을 탐지한다.
 * 같은 행 또는 직후 5행 이내 인접 영역을 검사.
 */
function extractEvidenceForLine(lines, idx) {
    const WINDOW = 5;
    for (let i = idx; i <= Math.min(idx + WINDOW, lines.length - 1); i++) {
        const m = lines[i].match(/근거\s*[:：]\s*(.+)/);
        if (m)
            return m[1].trim();
    }
    return null;
}
/**
 * 인용된 정책 파일에서 키워드가 매치되는지 확인한다.
 *
 * 인용 형식 예: `refs/policies/authentication-external.md` 또는
 *               `refs/policies/authentication-external.md L80-91`
 *
 * 키워드는 ⬜ 행 내 첫 번째 따옴표/백틱 토큰 또는 한국어 단어를 추정.
 * 매치 실패 시 false.
 */
function verifyEvidenceFile(cwd, evidence, itemText) {
    // 사용자 입력 / 운영 정책 / 사내 결정 등 비-정책 출처는 통과
    if (/^(사용자 입력|운영 정책|사내 결정|관리자 지정|N\/A|없음)/.test(evidence)) {
        return { ok: true, reason: "" };
    }
    const fileMatch = evidence.match(/(refs\/[^\s]+\.md)/);
    if (!fileMatch) {
        return {
            ok: false,
            reason: `근거 형식 오류 — refs/policies/*.md 경로 인용 또는 "사용자 입력" 명시 필요 (실제: "${evidence}")`,
        };
    }
    const relFile = fileMatch[1];
    const fullPath = path.join(cwd, relFile);
    if (!fs.existsSync(fullPath)) {
        return { ok: false, reason: `정책 파일 부재: ${relFile}` };
    }
    const policyContent = fs.readFileSync(fullPath, "utf-8");
    // 환경변수명(대문자_언더스코어) 또는 `백틱 토큰` 또는 따옴표 토큰을 키워드로 추출
    const tokens = new Set();
    const envVarMatches = itemText.match(/\b[A-Z][A-Z0-9_]{2,}\b/g) ?? [];
    for (const v of envVarMatches)
        tokens.add(v);
    const backtickMatches = itemText.match(/`([^`]+)`/g) ?? [];
    for (const v of backtickMatches)
        tokens.add(v.replace(/`/g, ""));
    if (tokens.size === 0) {
        // 추출 가능한 토큰 없으면 검증 생략 (느슨한 통과)
        return { ok: true, reason: "" };
    }
    const matched = [...tokens].some((tok) => policyContent.toLowerCase().includes(tok.toLowerCase()));
    if (!matched) {
        return {
            ok: false,
            reason: `정책 파일 ${relFile}에 항목 키워드 매치 없음 — 인용 부적합 (검색 토큰: ${[...tokens].join(", ")})`,
        };
    }
    return { ok: true, reason: "" };
}
export async function checkPrerequisitesGrounded() {
    const cwd = process.cwd();
    const ungrounded = [];
    let totalBlocked = 0;
    const files = findPrerequisitesFiles(cwd);
    for (const file of files) {
        const content = fs.readFileSync(file, "utf-8");
        const lines = content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            // 표 행에서 차단 마커 ⬜·🔴 등이 있고 차단 등급이 표시된 경우만 검사
            // 주의: "비차단"·"non-blocker"는 차단 키워드에서 제외
            if (!/⬜/.test(line))
                continue;
            const isBlocking = /🔴/.test(line) ||
                (/차단/.test(line) && !/비차단/.test(line)) ||
                (/blocker/i.test(line) && !/non-blocker/i.test(line));
            if (!isBlocking)
                continue;
            totalBlocked++;
            const evidence = extractEvidenceForLine(lines, i);
            if (!evidence) {
                ungrounded.push({
                    line: i + 1,
                    text: line.trim(),
                    reason: '근거 필드 없음 — `근거: refs/policies/{file}.md` 또는 `근거: 사용자 입력` 필요',
                });
                continue;
            }
            const v = verifyEvidenceFile(cwd, evidence, line);
            if (!v.ok) {
                ungrounded.push({ line: i + 1, text: line.trim(), reason: v.reason });
            }
        }
    }
    return {
        ok: ungrounded.length === 0,
        total_blocked_items: totalBlocked,
        ungrounded,
    };
}
//# sourceMappingURL=prerequisites-grounded.js.map