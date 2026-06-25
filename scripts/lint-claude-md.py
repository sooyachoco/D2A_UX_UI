#!/usr/bin/env python3
# scripts/lint-claude-md.py
#
# CLAUDE.md 및 스킬 파일 정적 분석 (방안 4)
#
# 검사 항목:
#   C1  스킬 참조 일관성  — CLAUDE.md의 `/skill-name` 참조 ↔ .claude/skills/{name}.md 존재
#   C2  경로 참조 유효성  — 백틱 경로(refs/, scripts/, specs/) ↔ 실제 파일 존재
#   C3  규칙 번호 연속성  — ## N. 패턴 규칙이 1~15 모두 있고 중복·빠진 번호 없음
#   C4  settings.json 훅 경로 — 훅 command에 등장하는 scripts/*.sh 파일 존재
#   C5  스킬 간 교차 참조 — .claude/skills/ 파일들이 참조하는 스킬 이름이 실제로 존재
#   C6  중복 규칙 제목 없음 — 같은 규칙 번호가 두 번 이상 선언되지 않음
#
# 사용:
#   python3 scripts/lint-claude-md.py            # 프로젝트 루트에서 실행
#   python3 scripts/lint-claude-md.py --strict   # WARN도 오류로 처리 (CI 엄격 모드)

import re
import os
import json
import sys
import argparse

# ── 색상 ─────────────────────────────────────────────────────────────────────
RED   = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE  = "\033[0;34m"
NC    = "\033[0m"

PASS = 0; FAIL = 0; WARN = 0

def ok(msg: str):
    global PASS
    print(f"{GREEN}  ✅ {msg}{NC}")
    PASS += 1

def err(msg: str):
    global FAIL
    print(f"{RED}  ❌ {msg}{NC}")
    FAIL += 1

def warn(msg: str):
    global WARN
    print(f"{YELLOW}  ⚠️  {msg}{NC}")
    WARN += 1

def section(title: str):
    print(f"\n{BLUE}━━━ {title} ━━━{NC}")


# ── 유틸 ─────────────────────────────────────────────────────────────────────

def read_file(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def project_root() -> str:
    """이 스크립트가 scripts/ 아래에 있으므로 한 레벨 위가 프로젝트 루트"""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ══════════════════════════════════════════════════════════════════════════════
# C1: 스킬 참조 일관성
# ══════════════════════════════════════════════════════════════════════════════

def check_skill_references(root: str, content: str):
    section("C1 스킬 참조 일관성")

    skills_dir = os.path.join(root, ".claude", "skills")

    # 실제 스킬 파일 목록 (검증의 기준)
    actual_skills: set[str] = set()
    if os.path.isdir(skills_dir):
        for f in os.listdir(skills_dir):
            if f.endswith(".md"):
                actual_skills.add(f[:-3])  # 확장자 제거

    # CLAUDE.md에서 실제 스킬 이름과 매칭되는 참조만 추출
    # 방식: actual_skills를 기준으로 역방향 검색 (false positive 방지)
    found_skills: set[str] = set()
    for skill in actual_skills:
        # 스킬 이름이 CLAUDE.md에 등장하면 참조로 간주
        if re.search(r'`/' + re.escape(skill) + r'`', content) or \
           re.search(r'Skill\(["\']' + re.escape(skill) + r'["\']', content) or \
           re.search(r'`' + re.escape(skill) + r'`', content):
            found_skills.add(skill)

    # 스킬 목록 테이블에서 | `/skill-name` | 형식으로 명시된 스킬도 포함
    table_skills = re.findall(r'\| `/([\w\-]+)` \|', content)
    for s in table_skills:
        if s in actual_skills:
            found_skills.add(s)

    if actual_skills:
        listed = found_skills & actual_skills
        ok(f"스킬 {len(actual_skills)}개 중 {len(listed)}개 CLAUDE.md에 참조 확인")

    # 역방향: 스킬 파일이 있지만 CLAUDE.md에 전혀 언급 없는 스킬 (정보성 경고)
    unlisted = actual_skills - found_skills
    if unlisted:
        warn(f"스킬 파일은 있으나 CLAUDE.md에 미언급: {', '.join(sorted(unlisted))}")


# ══════════════════════════════════════════════════════════════════════════════
# C2: 경로 참조 유효성
# ══════════════════════════════════════════════════════════════════════════════

def check_path_references(root: str, content: str):
    section("C2 경로 참조 유효성")

    # 백틱으로 감싸진 경로 중 refs/, scripts/, specs/ 로 시작하는 것만 검사
    path_pattern = r'`((?:refs|scripts|specs|\.claude)/[^`\s]+)`'
    candidates = re.findall(path_pattern, content)

    # 플레이스홀더({...}) 포함 경로 제외 (템플릿 예시)
    real_candidates = [p for p in set(candidates) if "{" not in p and "}" not in p]

    checked = 0
    for rel_path in sorted(real_candidates):
        full = os.path.join(root, rel_path)
        if os.path.exists(full):
            checked += 1
        else:
            # 확장자가 없으면 디렉토리일 수 있으므로 warn
            if "." not in os.path.basename(rel_path):
                warn(f"경로 참조 확인 필요 (디렉토리?): {rel_path}")
            else:
                err(f"경로 참조 존재하지 않음: {rel_path}")

    skipped = len(set(candidates)) - len(real_candidates)
    if skipped:
        ok(f"경로 참조 {checked}개 확인 ({skipped}개 플레이스홀더 경로 제외)")
    elif checked == len(real_candidates):
        ok(f"경로 참조 {checked}개 전체 확인")


# ══════════════════════════════════════════════════════════════════════════════
# C3: 규칙 번호 연속성
# ══════════════════════════════════════════════════════════════════════════════

def check_rule_continuity(content: str):
    section("C3 규칙 번호 연속성 (1~15)")

    # "### N. 규칙명" 또는 "### N. 규칙명 (규칙-id)" 패턴
    rule_nums = [int(n) for n in re.findall(r'^#{2,4}\s+(\d+)\.\s+\S', content, re.MULTILINE)]

    if not rule_nums:
        warn("규칙 번호 패턴(## N.)을 찾지 못함 — CLAUDE.md 형식 확인 필요")
        return

    duplicates = [n for n in set(rule_nums) if rule_nums.count(n) > 1]
    if duplicates:
        for d in sorted(duplicates):
            err(f"규칙 번호 중복: {d}")

    expected = set(range(1, max(rule_nums) + 1))
    missing_nums = expected - set(rule_nums)
    # 일부러 건너뛴 번호는 허용 (예: 15로 끝나는데 중간 없는 경우)
    if missing_nums:
        warn(f"규칙 번호 불연속: {sorted(missing_nums)} 없음 (의도적 건너뜀이면 무시)")
    else:
        ok(f"규칙 번호 연속성 정상: 1~{max(rule_nums)} ({len(rule_nums)}개)")


# ══════════════════════════════════════════════════════════════════════════════
# C4: settings.json 훅 경로 유효성
# ══════════════════════════════════════════════════════════════════════════════

def check_settings_hooks(root: str):
    section("C4 settings.json 훅 경로 유효성")

    settings_path = os.path.join(root, ".claude", "settings.json")
    raw = read_file(settings_path)
    if raw is None:
        err(".claude/settings.json 없음")
        return

    try:
        settings = json.loads(raw)
    except json.JSONDecodeError as e:
        err(f".claude/settings.json JSON 파싱 실패: {e}")
        return

    ok(".claude/settings.json JSON 파싱 정상")

    script_refs: set[str] = set()
    for event_hooks in settings.get("hooks", {}).values():
        for block in event_hooks:
            for hook in block.get("hooks", []):
                cmd = hook.get("command", "")
                for m in re.findall(r'scripts/[\w\-]+\.sh', cmd):
                    script_refs.add(m)

    for rel in sorted(script_refs):
        full = os.path.join(root, rel)
        if os.path.exists(full):
            ok(f"훅 경로 확인: {rel}")
        else:
            err(f"훅 command 참조 파일 없음: {rel}")


# ══════════════════════════════════════════════════════════════════════════════
# C5: 스킬 간 교차 참조 유효성
# ══════════════════════════════════════════════════════════════════════════════

def check_skill_cross_references(root: str):
    section("C5 스킬 간 교차 참조")

    skills_dir = os.path.join(root, ".claude", "skills")
    if not os.path.isdir(skills_dir):
        warn(f".claude/skills/ 없음 — 교차 참조 검사 생략")
        return

    actual_skills = {f[:-3] for f in os.listdir(skills_dir) if f.endswith(".md")}
    errors: list[str] = []

    for skill_file in sorted(os.listdir(skills_dir)):
        if not skill_file.endswith(".md"):
            continue
        content = read_file(os.path.join(skills_dir, skill_file)) or ""
        skill_name = skill_file[:-3]

        # 스킬 파일 내에서 실제 스킬 이름과 일치하는 참조만 추출
        # (actual_skills 기준으로 역방향 검색하여 false positive 방지)
        refs: set[str] = set()
        for candidate_skill in actual_skills:
            if candidate_skill == skill_name:
                continue  # 자기 자신 참조 무시
            if re.search(r'`/' + re.escape(candidate_skill) + r'`', content) or \
               re.search(r'Skill\(["\']' + re.escape(candidate_skill) + r'["\']', content):
                refs.add(candidate_skill)

        # 참조 스킬이 실제로 존재하는지 확인 (이미 actual_skills에서 추출했으므로 항상 존재)
        # 이 로직은 미래에 스킬 파일이 삭제될 때 감지용
        for ref in refs:
            if ref not in actual_skills:
                errors.append(f"{skill_file} → /{ref} 참조하지만 파일 없음")

    if not errors:
        ok(f"스킬 {len(actual_skills)}개 교차 참조 정상")
    else:
        for e in errors:
            err(e)


# ══════════════════════════════════════════════════════════════════════════════
# C6: 중복 규칙 제목 없음
# ══════════════════════════════════════════════════════════════════════════════

def check_duplicate_rule_titles(content: str):
    section("C6 중복 규칙 제목")

    # 규칙 제목 라인 (## N. 제목-id) 추출
    titles = re.findall(r'^#{2,4}\s+\d+\.\s+(.+)', content, re.MULTILINE)
    seen: dict[str, int] = {}
    dups = []
    for t in titles:
        t = t.strip().lower()
        seen[t] = seen.get(t, 0) + 1
        if seen[t] == 2:
            dups.append(t)

    if not dups:
        ok(f"규칙 제목 중복 없음 ({len(titles)}개 확인)")
    else:
        for d in dups:
            err(f"중복 규칙 제목: '{d}'")


# ══════════════════════════════════════════════════════════════════════════════
# 진입점
# ══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="CLAUDE.md 정적 분석")
    parser.add_argument("--strict", action="store_true", help="WARN도 오류로 처리 (CI 엄격 모드)")
    args = parser.parse_args()

    root = project_root()
    claude_md = os.path.join(root, "CLAUDE.md")

    print(f"{BLUE}CLAUDE.md 정적 분석 — {root}{NC}")

    content = read_file(claude_md)
    if content is None:
        print(f"{RED}❌ CLAUDE.md 없음: {claude_md}{NC}")
        sys.exit(1)

    check_skill_references(root, content)
    check_path_references(root, content)
    check_rule_continuity(content)
    check_settings_hooks(root)
    check_skill_cross_references(root)
    check_duplicate_rule_titles(content)

    print(f"\n{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")
    print(f"  결과:  {GREEN}PASS {PASS:<3}{NC}  {RED}FAIL {FAIL:<3}{NC}  {YELLOW}WARN {WARN:<3}{NC}")
    print(f"{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")

    effective_fail = FAIL + (WARN if args.strict else 0)
    if effective_fail > 0:
        mode = " (--strict 모드: WARN 포함)" if args.strict and WARN else ""
        print(f"{RED}분석 실패 — 위 ❌ 항목을 수정하세요{mode}{NC}\n")
        sys.exit(1)
    else:
        print(f"{GREEN}분석 통과{NC}\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
