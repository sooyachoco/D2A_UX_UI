// UT Severity 게이트 — 순수 함수 (파일/셸 의존 없음 → Workers 이식 가능).
// d2a-mcp-server 의 checkUtReport 로직을 원격 MCP 용으로 포팅한 것.
// 입력: UT_FINDINGS_REPORT.md 본문 + 규칙 문자열("S4=0,S3<=2")

export interface UtGateResult {
  passed: boolean;
  reason: string;
  counts: Record<string, number>;
  checked: string[];
}

/** 리포트 본문에서 S1~S4 카운트를 추출하고 규칙을 평가한다. */
export function evaluateUtGate(report: string, criteria: string): UtGateResult {
  const counts: Record<string, number> = {};
  for (const level of ["S1", "S2", "S3", "S4"]) {
    // 같은 줄에 S{n} 과 숫자가 함께 있는 첫 매칭을 카운트로 본다.
    const re = new RegExp(`${level}\\b[^\\d\\n]*?(\\d+)`, "i");
    const m = report.match(re);
    if (m) counts[level] = parseInt(m[1], 10);
  }

  if (Object.keys(counts).length === 0) {
    return {
      passed: false,
      reason: "Severity 카운트(S1~S4)를 리포트에서 찾지 못함 — Executive Summary 표 형식을 확인하세요.",
      counts,
      checked: [],
    };
  }

  const rules = criteria.split(",").map((s) => s.trim()).filter(Boolean);
  const failures: string[] = [];
  const checked: string[] = [];

  for (const rule of rules) {
    const rm = rule.match(/^(S[1-4])\s*(==|!=|<=|>=|=|<|>)\s*(\d+)$/i);
    if (!rm) {
      failures.push(`잘못된 규칙 형식: "${rule}" (예: S4=0, S3<=2)`);
      continue;
    }
    const level = rm[1].toUpperCase();
    const op = rm[2];
    const expected = parseInt(rm[3], 10);
    const actual = counts[level];

    if (actual === undefined) {
      failures.push(`${level} 카운트를 리포트에서 찾지 못함`);
      continue;
    }

    let ok: boolean;
    switch (op) {
      case "=":
      case "==": ok = actual === expected; break;
      case "!=": ok = actual !== expected; break;
      case "<": ok = actual < expected; break;
      case "<=": ok = actual <= expected; break;
      case ">": ok = actual > expected; break;
      case ">=": ok = actual >= expected; break;
      default: ok = false;
    }

    checked.push(`${level}=${actual} ${ok ? "✓" : "✗"}(${op}${expected})`);
    if (!ok) failures.push(`${level}=${actual} 위반 (요구: ${op}${expected})`);
  }

  if (failures.length > 0) {
    return {
      passed: false,
      reason: `UT 임계 미충족: ${failures.join("; ")} | 관측: ${checked.join(", ")}`,
      counts,
      checked,
    };
  }

  return {
    passed: true,
    reason: `UT 임계 통과: ${checked.join(", ")}`,
    counts,
    checked,
  };
}
