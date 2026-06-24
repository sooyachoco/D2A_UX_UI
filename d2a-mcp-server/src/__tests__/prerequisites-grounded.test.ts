import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { checkPrerequisitesGrounded } from "../tools/prerequisites-grounded.js";
import { createTempGitRepo, mockCwd } from "./helpers.js";

describe("checkPrerequisitesGrounded", () => {
  let dir: string;
  let cleanup: () => void;
  let cwdSpy: ReturnType<typeof import("vitest").vi.spyOn>;

  afterEach(() => {
    cwdSpy?.mockRestore();
    cleanup?.();
  });

  function setup() {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, "specs/001-app"), { recursive: true });
    mkdirSync(join(dir, "refs/policies"), { recursive: true });
  }

  it("근거 필드 없는 ⬜ 차단 항목은 ungrounded로 보고된다", async () => {
    setup();
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      [
        "| 항목 | 차단 등급 | 상태 | 환경변수명 |",
        "|---|---|---|---|",
        "| 가짜 키 | 🔴 차단 | ⬜ | `GAMESCALE_API_KEY` |",
      ].join("\n"),
      "utf-8"
    );
    const result = await checkPrerequisitesGrounded();
    expect(result.ok).toBe(false);
    expect(result.total_blocked_items).toBe(1);
    expect(result.ungrounded[0].reason).toMatch(/근거 필드 없음/);
  });

  it("`근거: 사용자 입력` 명시는 통과한다", async () => {
    setup();
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      [
        "| 항목 | 차단 등급 | 상태 | 환경변수명 |",
        "|---|---|---|---|",
        "| GID | 🔴 차단 | ⬜ | `VITE_GID` |",
        "근거: 사용자 입력",
      ].join("\n"),
      "utf-8"
    );
    const result = await checkPrerequisitesGrounded();
    expect(result.ok).toBe(true);
    expect(result.ungrounded).toHaveLength(0);
  });

  it("정책 파일 인용 + 키워드 매치 시 통과한다", async () => {
    setup();
    writeFileSync(
      join(dir, "refs/policies/authentication-external.md"),
      "INSIGN 인증은 `_ifwt` 쿠키 기반. `VITE_INFACE_WEB_AUTH` 환경변수에 도메인 지정.",
      "utf-8"
    );
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      [
        "| 항목 | 차단 등급 | 상태 | 환경변수명 |",
        "|---|---|---|---|",
        "| INSIGN 도메인 | 🔴 차단 | ⬜ | `VITE_INFACE_WEB_AUTH` |",
        "근거: refs/policies/authentication-external.md",
      ].join("\n"),
      "utf-8"
    );
    const result = await checkPrerequisitesGrounded();
    expect(result.ok).toBe(true);
  });

  it("정책 파일 인용했으나 키워드 매치 0건이면 차단", async () => {
    setup();
    writeFileSync(
      join(dir, "refs/policies/authentication-external.md"),
      "INSIGN은 `_ifwt` 쿠키 기반. OAuth 흐름 사용하지 않음.",
      "utf-8"
    );
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      [
        "| 항목 | 차단 등급 | 상태 | 환경변수명 |",
        "|---|---|---|---|",
        "| Callback URL | 🔴 차단 | ⬜ | `NCSR_CALLBACK_URL` |",
        "근거: refs/policies/authentication-external.md",
      ].join("\n"),
      "utf-8"
    );
    const result = await checkPrerequisitesGrounded();
    expect(result.ok).toBe(false);
    expect(result.ungrounded[0].reason).toMatch(/키워드 매치 없음/);
  });

  it("정책 파일 인용했으나 파일 부재면 차단", async () => {
    setup();
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      [
        "| 항목 | 차단 등급 | 상태 | 환경변수명 |",
        "|---|---|---|---|",
        "| 가짜 키 | 🔴 차단 | ⬜ | `FAKE_KEY` |",
        "근거: refs/policies/nonexistent.md",
      ].join("\n"),
      "utf-8"
    );
    const result = await checkPrerequisitesGrounded();
    expect(result.ok).toBe(false);
    expect(result.ungrounded[0].reason).toMatch(/정책 파일 부재/);
  });

  it("⬜ 마커 있지만 차단 등급 없으면 검증 생략", async () => {
    setup();
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      [
        "| 항목 | 차단 등급 | 상태 | 환경변수명 |",
        "|---|---|---|---|",
        "| 기능 옵션 | 🟢 비차단 | ⬜ | `FEATURE_FLAG` |",
      ].join("\n"),
      "utf-8"
    );
    const result = await checkPrerequisitesGrounded();
    expect(result.ok).toBe(true);
    expect(result.total_blocked_items).toBe(0);
  });
});
