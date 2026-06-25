#!/usr/bin/env python3
"""
scripts/status-html.py
D2A 파생 프로젝트 진행상태를 단일 self-contained HTML 대시보드로 생성한다.

데이터 소스 (읽기 전용, 4곳):
  - .claude/state.json                머신 상태 (phase/status/current_task/blockers)
  - specs/*/tasks.md | tasks.md       태스크 ☑/☐ 진행률
  - PROGRESS.md | specs/*/PROGRESS.md 현재 단계 텍스트 / review_status
  - logs/boilerplate-activity.md      최근 활동 타임라인

출력: .claude/status.html
  - 데이터를 HTML에 인라인 주입한 self-contained 단일 파일 (file://로 바로 열림, 서버 불필요)
  - <meta refresh>로 30초마다 자동 새로고침 → 보고 있는 동안 라이브
  - .gitignore 대상 (state.json 과 동일하게 산출물로 취급)

갱신: Stop hook(매 응답 종료)에서 자동 호출. 수동 확인: python3 scripts/status-html.py
이 스크립트는 어떤 소스도 수정하지 않는다. 읽기 전용.
"""

import glob
import html
import json
import os
import re
from datetime import datetime, timezone

# ──────────────────────────────────────────────────────────────────────────
# 경로 해석 — 파생 프로젝트 루트(cwd)에서 실행되는 것을 전제로 한다.
# ──────────────────────────────────────────────────────────────────────────
ROOT = os.getcwd()
OUT_PATH = os.path.join(ROOT, ".claude", "status.html")


def _first_existing(*candidates):
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


def _first_glob(pattern, exclude_substr=".template"):
    """패턴에 매칭되는 첫 파일 (.template 제외, 이름순)."""
    matches = sorted(g for g in glob.glob(pattern) if exclude_substr not in g)
    return matches[0] if matches else None


def find_tasks_md():
    return _first_glob(os.path.join(ROOT, "specs", "*", "tasks.md")) or _first_existing(
        os.path.join(ROOT, "tasks.md")
    )


def find_progress_md():
    return _first_existing(os.path.join(ROOT, "PROGRESS.md")) or _first_glob(
        os.path.join(ROOT, "specs", "*", "PROGRESS.md")
    )


def find_activity_md():
    return _first_existing(os.path.join(ROOT, "logs", "boilerplate-activity.md"))


# ──────────────────────────────────────────────────────────────────────────
# 1) state.json
# ──────────────────────────────────────────────────────────────────────────
def read_state():
    path = os.path.join(ROOT, ".claude", "state.json")
    if not os.path.isfile(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


# ──────────────────────────────────────────────────────────────────────────
# 2) tasks.md  →  [{phase, name, header_done, tasks: [{id, title, done}]}]
# ──────────────────────────────────────────────────────────────────────────
PHASE_RE = re.compile(r"^##\s+Phase\s+([0-9.]+)\s*:?\s*(.*?)\s*(☑|✅)?\s*$")
TASK_RE = re.compile(r"^###\s+(T[\w-]+)\s*:?\s*(.*)$")
STATUS_RE = re.compile(r"\*\*status\*\*\s*:\s*(☑|☐|✅|⬜)")
DONE_MARKS = {"☑", "✅"}


def read_tasks(path, completed_set):
    if not path:
        return []
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return []

    phases = []
    cur_phase = None
    cur_task = None

    def close_task():
        nonlocal cur_task
        if cur_task and cur_phase is not None:
            cur_phase["tasks"].append(cur_task)
        cur_task = None

    for line in lines:
        mp = PHASE_RE.match(line)
        if mp:
            close_task()
            cur_phase = {
                "phase": mp.group(1),
                "name": mp.group(2).strip() or f"Phase {mp.group(1)}",
                "header_done": bool(mp.group(3)),
                "tasks": [],
            }
            phases.append(cur_phase)
            continue

        mt = TASK_RE.match(line)
        if mt and cur_phase is not None:
            close_task()
            tid = mt.group(1)
            cur_task = {
                "id": tid,
                "title": mt.group(2).strip(),
                "done": tid in completed_set,  # state.completed_tasks 우선 보강
            }
            continue

        if cur_task is not None:
            ms = STATUS_RE.search(line)
            if ms:
                if ms.group(1) in DONE_MARKS:
                    cur_task["done"] = True

    close_task()
    return phases


# ──────────────────────────────────────────────────────────────────────────
# 3) PROGRESS.md  →  현재 단계 / review_status (표 셀 텍스트)
# ──────────────────────────────────────────────────────────────────────────
def read_progress(path):
    info = {"stage": None, "review_status": None, "last_work": None}
    if not path:
        return info
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return info

    def cell(label):
        m = re.search(r"\|\s*\*\*" + re.escape(label) + r"\*\*\s*\|\s*(.*?)\s*\|", text)
        return m.group(1).strip() if m else None

    info["stage"] = cell("현재 단계")
    info["review_status"] = cell("review_status")
    info["last_work"] = cell("마지막 작업")
    return info


# ──────────────────────────────────────────────────────────────────────────
# 4) activity 로그  →  최근 N건
# ──────────────────────────────────────────────────────────────────────────
ACT_RE = re.compile(r"^-\s+`([^`]+)`\s+\*\*\[([A-Z]+)\]\*\*\s+(.*)$")


def read_activity(path, limit=12):
    if not path:
        return []
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return []
    items = []
    for line in lines:
        m = ACT_RE.match(line)
        if m:
            items.append({"ts": m.group(1), "cat": m.group(2), "title": m.group(3)})
    return items[-limit:][::-1]  # 최신순


# ──────────────────────────────────────────────────────────────────────────
# 보조: 상대 시각 ("N분 전")
# ──────────────────────────────────────────────────────────────────────────
def humanize_ago(iso_str):
    if not iso_str:
        return None
    for parser in (
        lambda s: datetime.fromisoformat(s.replace("Z", "+00:00")),
    ):
        try:
            dt = parser(iso_str)
            break
        except (ValueError, TypeError):
            dt = None
    if dt is None:
        return None
    now = datetime.now(timezone.utc) if dt.tzinfo else datetime.now()
    delta = now - dt
    secs = int(delta.total_seconds())
    if secs < 0:
        return "방금"
    if secs < 60:
        return f"{secs}초 전"
    if secs < 3600:
        return f"{secs // 60}분 전"
    if secs < 86400:
        return f"{secs // 3600}시간 전"
    return f"{secs // 86400}일 전"


def norm_phase(v):
    """state.phase(숫자) → tasks.md 헤더 문자열('0.5','1')과 매칭되도록 정규화."""
    if v is None:
        return None
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


# ──────────────────────────────────────────────────────────────────────────
# HTML 렌더링
# ──────────────────────────────────────────────────────────────────────────
STATUS_META = {
    "idle": ("대기", "muted"),
    "running": ("진행 중", "accent"),
    "blocked": ("차단됨", "red"),
    "waiting": ("입력 대기", "yellow"),
    "complete": ("완료", "green"),
}

CAT_COLOR = {
    "PHASE": "accent", "TASK": "green", "REVIEW": "accent", "DECISION": "yellow",
    "BLOCKED": "red", "BUILD": "muted", "COMMIT": "green", "SOURCE": "muted",
    "POLICY": "muted", "SETUP": "accent", "MCP": "muted", "SKILL": "muted",
    "COLLAB": "yellow", "SLACK": "muted",
}

# 활동 카테고리를 업무 친화적 한글 표현으로 (개발 용어 → 기능 용어)
CAT_LABEL = {
    "PHASE": "단계", "TASK": "작업", "REVIEW": "검토", "DECISION": "결정",
    "BLOCKED": "막힘", "BUILD": "검증", "COMMIT": "저장", "SOURCE": "수정",
    "POLICY": "정책", "SETUP": "설정", "MCP": "시스템", "SKILL": "실행",
    "COLLAB": "협업", "SLACK": "알림",
}


def esc(s):
    return html.escape(str(s)) if s is not None else ""


def render(state, phases, progress, activity, project_name, activity_path=None):
    gen_now = datetime.now()
    state_ago = humanize_ago(state.get("last_updated")) or "—"

    raw_status = state.get("status") or "idle"
    status_label, status_color = STATUS_META.get(raw_status, (raw_status, "muted"))

    cur_phase = norm_phase(state.get("phase"))
    cur_task = state.get("current_task")
    blockers = state.get("blockers") or []

    # 단계 텍스트: PROGRESS.md 우선, 없으면 state 기반
    stage_text = progress.get("stage")
    if not stage_text:
        stage_text = f"{cur_phase}단계" if cur_phase is not None else "준비 단계"

    # 검토 상태: 영어/기호를 업무 표현으로 정규화
    rs_raw = (progress.get("review_status") or "—").strip()
    if "pending" in rs_raw.lower() or "⏳" in rs_raw:
        review_status = "⏳ 검토 대기"
    elif "✅" in rs_raw:
        date_part = rs_raw.replace("✅", "").strip()
        review_status = "✅ 검토 완료" + (f" ({date_part})" if date_part else "")
    elif rs_raw.upper() in ("N/A", "NA"):
        review_status = "해당 없음"
    else:
        review_status = rs_raw

    # 현재 작업: ID 대신 작업 이름을 노출(ID는 마우스오버)
    cur_task_title = None
    if cur_task:
        for p in phases:
            for t in p["tasks"]:
                if t["id"] == cur_task:
                    cur_task_title = t["title"]
                    break
            if cur_task_title:
                break

    # 전체 진행률
    all_tasks = [t for p in phases for t in p["tasks"]]
    total = len(all_tasks)
    done = sum(1 for t in all_tasks if t["done"])
    pct = round(done / total * 100) if total else 0

    # ── 블로커 배너 ──
    blocker_html = ""
    if blockers:
        rows = "".join(
            f'<li><span class="bk-task">{esc(b.get("task","?"))}</span>'
            f'<span class="bk-reason">{esc(b.get("reason",""))}</span>'
            f'<span class="bk-since">{esc(humanize_ago(b.get("since")) or "")}</span></li>'
            for b in blockers
        )
        blocker_html = (
            f'<section class="banner banner-red"><div class="banner-h">⛔ 막힌 작업 '
            f'{len(blockers)}건 — 진행 멈춤</div><ul class="bk-list">{rows}</ul></section>'
        )

    # ── Phase 카드 ──
    cards = []
    for p in phases:
        ptasks = p["tasks"]
        pdone = sum(1 for t in ptasks if t["done"])
        ptotal = len(ptasks)
        ppct = round(pdone / ptotal * 100) if ptotal else (100 if p["header_done"] else 0)
        is_current = (cur_phase is not None and p["phase"] == cur_phase)
        is_complete = ptotal > 0 and pdone == ptotal or (ptotal == 0 and p["header_done"])

        state_cls = "ph-current" if is_current else ("ph-done" if is_complete else "ph-todo")
        marker = "▶" if is_current else ("✓" if is_complete else "○")

        chips = ""
        # 현재 Phase거나 미완료 Phase는 태스크 칩을 펼친다 (완료 Phase는 접어 노이즈 감소)
        if ptasks and (is_current or not is_complete):
            chip_items = []
            for t in ptasks:
                cc = "chip-done" if t["done"] else "chip-todo"
                if t["id"] == cur_task:
                    cc += " chip-active"
                # 작업 이름을 우선 노출(기능적), ID는 마우스오버로
                label = t["title"] or t["id"]
                chip_items.append(
                    f'<span class="chip {cc}" title="{esc(t["id"])}">'
                    f'{"☑" if t["done"] else "☐"} {esc(label)}</span>'
                )
            chips = f'<div class="chips">{"".join(chip_items)}</div>'

        cards.append(
            f'<div class="ph-card {state_cls}">'
            f'<div class="ph-top"><span class="ph-marker">{marker}</span>'
            f'<span class="ph-name">{esc(p["phase"])}단계 · {esc(p["name"])}</span>'
            f'<span class="ph-count">{pdone}/{ptotal}</span></div>'
            f'<div class="bar"><div class="bar-fill" style="width:{ppct}%"></div></div>'
            f'{chips}</div>'
        )
    cards_html = "".join(cards) or '<p class="empty">아직 작업 목록이 없습니다 — 기능 명세 작성 단계입니다.</p>'

    # ── 최근 활동 ──
    act_rows = "".join(
        f'<li><span class="act-cat cat-{CAT_COLOR.get(a["cat"],"muted")}">{esc(CAT_LABEL.get(a["cat"], a["cat"]))}</span>'
        f'<span class="act-title">{esc(a["title"])}</span>'
        f'<span class="act-ts">{esc(a["ts"].split()[-1] if a["ts"] else "")}</span></li>'
        for a in activity
    ) or '<li class="empty">최근 활동이 없습니다</li>'

    # 전체 로그 링크: status.html(.claude/)에서 logs/ 로의 상대경로
    more_link = ""
    if activity_path:
        more_link = '<a class="more-link" href="../logs/boilerplate-activity.md">전체 활동 로그 보기 →</a>'

    if cur_task:
        disp = cur_task_title or cur_task
        cur_task_html = f'<span title="{esc(cur_task)}">{esc(disp)}</span>'
    else:
        cur_task_html = '<span class="muted">없음</span>'

    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta http-equiv="refresh" content="30" />
<title>D2A 진행 현황 · {esc(project_name)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
<style>
:root {{
  /* Swiss / International Typographic — 무채색 + 검정 헤어라인 + 단일 적색 accent */
  --bg:#ffffff; --surface:#ffffff; --surface2:#f4f4f4; --surface3:#e9e9e9;
  --border:#000000; --border-soft:#d8d8d8;
  --accent:#e8341c; --accent-soft:#c12a14; --accent-glow:rgba(232,52,28,0.07);
  --green:#1a7f37; --red:#e8341c; --yellow:#9a7d00;
  /* 텍스트 위계 — 잉크 블랙 기준 */
  --text:#000000; --text-dim:#1c1c1c; --muted:#555555; --muted-soft:#8a8a8a;
  --radius:0px; --radius-sm:0px;
  --serif:'Inter','Helvetica Neue',Arial,'Pretendard','Apple SD Gothic Neo',sans-serif;
  --sans:'Inter','Helvetica Neue',Arial,'Pretendard','Apple SD Gothic Neo',sans-serif;
  --mono:'JetBrains Mono','SF Mono',Consolas,monospace;
}}
* {{ box-sizing:border-box; margin:0; padding:0; }}
body {{ background:var(--bg); color:var(--text); font-family:var(--sans);
  font-size:15px; line-height:1.6; -webkit-font-smoothing:antialiased; padding:32px 24px 64px;
  font-variant-numeric:tabular-nums; }}  /* 데이터/숫자 정렬 */
.wrap {{ max-width:1040px; margin:0 auto; }}
code {{ font-family:var(--mono); background:var(--surface2); padding:1px 6px; border-radius:4px;
  font-size:0.9em; color:var(--accent); }}
.muted {{ color:var(--muted); }}

/* 헤더 */
.head {{ display:flex; justify-content:space-between; align-items:flex-end;
  border-bottom:2.5px solid var(--text); padding-bottom:18px; margin-bottom:24px; flex-wrap:wrap; gap:12px; }}
.head h1 {{ font-family:var(--sans); font-size:26px; font-weight:800; letter-spacing:-0.03em; text-transform:uppercase; }}
.head h1 .dim {{ color:var(--muted-soft); font-weight:400; text-transform:none; }}
.head .meta {{ text-align:right; font-size:12.5px; color:var(--muted); }}
.head .meta b {{ color:var(--text-dim); }}

/* 상태 배지 줄 */
.badges {{ display:flex; gap:10px; flex-wrap:wrap; margin-bottom:26px; }}
.badge {{ background:var(--surface); border:0; border-top:1.5px solid var(--text); border-radius:0;
  padding:13px 16px 12px; min-width:150px; }}
.badge .k {{ font-size:11px; text-transform:uppercase; letter-spacing:0.07em; color:var(--muted-soft); margin-bottom:5px; }}
.badge .v {{ font-size:15px; font-weight:600; color:var(--text); }}
.dot {{ display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:7px; vertical-align:middle; }}
.c-accent {{ color:var(--accent); }} .bg-accent {{ background:var(--accent); }}
.c-green {{ color:var(--green); }}  .bg-green {{ background:var(--green); }}
.c-red {{ color:var(--red); }}      .bg-red {{ background:var(--red); }}
.c-yellow {{ color:var(--yellow); }} .bg-yellow {{ background:var(--yellow); }}
.c-muted {{ color:var(--muted); }}  .bg-muted {{ background:var(--muted-soft); }}

/* 전체 진행률 */
.overall {{ background:var(--surface); border:0; border-top:1.5px solid var(--text); border-radius:0;
  padding:16px 20px 20px; margin-bottom:26px; }}
/* 진행률 — 큰 숫자를 좌상단에 (F-패턴 스캔 동선) */
.overall .ov-label {{ font-size:12px; color:var(--muted); text-transform:uppercase; letter-spacing:0.07em; margin-bottom:6px; }}
.overall .ov-num {{ font-family:var(--sans); font-size:34px; font-weight:800; line-height:1; margin-bottom:14px; letter-spacing:-0.02em; }}
.overall .ov-num small {{ font-size:14px; color:var(--muted); font-weight:500; font-family:var(--sans); }}

.bar {{ height:6px; background:var(--surface3); border-radius:0; overflow:hidden; }}
.bar-fill {{ height:100%; background:var(--text); border-radius:0; transition:width .3s; }}
.overall .bar {{ height:10px; }}

/* 섹션 제목 */
.sec-title {{ font-family:var(--sans); font-size:13px; font-weight:700; margin:30px 0 14px;
  text-transform:uppercase; letter-spacing:0.06em; border-top:2.5px solid var(--text); padding-top:10px;
  display:flex; align-items:center; gap:8px; }}
.sec-title::before {{ display:none; }}

/* Phase 카드 */
.ph-card {{ background:var(--surface); border:0; border-top:1.5px solid var(--text); border-left:3px solid transparent;
  border-radius:0; padding:13px 16px; margin-bottom:0; }}
.ph-card.ph-current {{ border-left-color:var(--accent); background:var(--surface); }}
.ph-card.ph-current .bar-fill {{ background:var(--accent); }}
.ph-card.ph-done {{ border-left-color:var(--text); opacity:1; }}
.ph-card.ph-done .bar-fill {{ background:var(--text); }}
.ph-card.ph-todo {{ opacity:0.5; }}
.ph-top {{ display:flex; align-items:center; gap:10px; margin-bottom:9px; }}
.ph-marker {{ width:16px; text-align:center; color:var(--muted); font-size:13px; }}
.ph-current .ph-marker {{ color:var(--accent); }}
.ph-done .ph-marker {{ color:var(--green); }}
.ph-name {{ flex:1; font-weight:600; font-size:14.5px; }}
.ph-count {{ font-family:var(--mono); font-size:12.5px; color:var(--muted); }}
.chips {{ display:flex; flex-wrap:wrap; gap:6px; margin-top:11px; }}
.chip {{ font-size:11.5px; padding:3px 11px; border-radius:0;
  border:1px solid var(--text); background:var(--surface);
  max-width:230px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
  display:inline-block; vertical-align:middle; }}
.chip-done {{ color:var(--green); border-color:var(--green); }}
.chip-todo {{ color:var(--muted); }}
.chip-active {{ border-color:var(--accent); color:var(--accent); font-weight:600; }}

/* 블로커 배너 */
.banner {{ border-radius:0; padding:14px 18px; margin-bottom:22px; }}
.banner-red {{ background:#fff0ee; border:0; border-top:3px solid var(--accent); }}
.banner-h {{ font-weight:700; color:var(--accent); margin-bottom:8px; }}
.bk-list {{ list-style:none; }}
.bk-list li {{ display:flex; gap:12px; align-items:baseline; padding:3px 0; font-size:13.5px; }}
.bk-task {{ font-family:var(--mono); color:var(--text); min-width:90px; }}
.bk-reason {{ flex:1; color:var(--text-dim); }}
.bk-since {{ color:var(--muted-soft); font-size:12px; }}

/* 최근 활동 */
.acts {{ list-style:none; background:var(--surface); border:0; border-top:1.5px solid var(--text); border-radius:0; overflow:hidden; }}
.acts li {{ display:flex; gap:12px; align-items:center; padding:9px 16px; border-bottom:1px solid var(--border-soft); font-size:13px; }}
.acts li:last-child {{ border-bottom:none; }}
.act-cat {{ font-size:11px; font-weight:600; padding:2px 9px; border-radius:0;
  min-width:52px; text-align:center; background:var(--surface); border:1px solid var(--text); }}
.cat-accent {{ color:var(--accent); }} .cat-green {{ color:var(--green); }}
.cat-red {{ color:var(--red); }} .cat-yellow {{ color:var(--yellow); }} .cat-muted {{ color:var(--muted); }}
.act-title {{ flex:1; color:var(--text-dim); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }}
.act-ts {{ font-family:var(--mono); font-size:11px; color:var(--muted-soft); }}
.empty {{ color:var(--muted-soft); padding:14px 16px; font-style:italic; }}
.more-link {{ display:inline-block; margin-top:11px; font-size:12.5px; color:var(--muted);
  text-decoration:none; border-bottom:1px solid var(--border); padding-bottom:1px; }}
.more-link:hover {{ color:var(--accent); border-color:var(--accent); }}

.foot {{ margin-top:34px; padding-top:14px; border-top:1px solid var(--border-soft);
  font-size:11.5px; color:var(--muted-soft); display:flex; justify-content:space-between; flex-wrap:wrap; gap:8px; }}
</style>
</head>
<body>
<div class="wrap">

  <header class="head">
    <h1>{esc(project_name)} <span class="dim">진행 현황</span></h1>
    <div class="meta">
      상태 갱신 <b>{esc(state_ago)}</b><br>
      화면 생성 {gen_now.strftime("%Y-%m-%d %H:%M:%S")}
    </div>
  </header>

  {blocker_html}

  <div class="badges">
    <div class="badge"><div class="k">현재 단계</div><div class="v">{esc(stage_text)}</div></div>
    <div class="badge"><div class="k">상태</div><div class="v c-{status_color}"><span class="dot bg-{status_color}"></span>{esc(status_label)}</div></div>
    <div class="badge"><div class="k">현재 작업</div><div class="v">{cur_task_html}</div></div>
    <div class="badge"><div class="k">검토 상태</div><div class="v">{esc(review_status)}</div></div>
  </div>

  <div class="overall">
    <div class="ov-label">전체 진행률</div>
    <div class="ov-num">{pct}%<small> · {done}/{total} 완료</small></div>
    <div class="bar"><div class="bar-fill" style="width:{pct}%"></div></div>
  </div>

  <div class="sec-title">단계별 진행 현황</div>
  {cards_html}

  <div class="sec-title">최근 활동</div>
  <ul class="acts">{act_rows}</ul>
  {more_link}

  <div class="foot">
    <span>현재 진행 상황 요약 · 작업이 끝날 때마다 자동 갱신 · 30초마다 새로고침</span>
    <span>D2A 진행 대시보드</span>
  </div>

</div>
</body>
</html>
"""


# ──────────────────────────────────────────────────────────────────────────
def main():
    state = read_state()
    completed_set = set(state.get("completed_tasks") or [])

    tasks_path = find_tasks_md()
    progress_path = find_progress_md()
    activity_path = find_activity_md()

    phases = read_tasks(tasks_path, completed_set)
    progress = read_progress(progress_path)
    activity = read_activity(activity_path)

    # 프로젝트 이름: specs/{name}/ 우선, 없으면 루트 디렉토리명
    project_name = os.path.basename(ROOT)
    if tasks_path:
        spec_dir = os.path.basename(os.path.dirname(tasks_path))
        if spec_dir and spec_dir not in (".template", "specs", os.path.basename(ROOT)):
            project_name = spec_dir

    html_out = render(state, phases, progress, activity, project_name, activity_path)

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(html_out)
    print(f"status-html: wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
