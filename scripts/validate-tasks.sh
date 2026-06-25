#!/usr/bin/env bash
# scripts/validate-tasks.sh
# tasks.md 스키마 검증 — 필수 필드 누락 태스크 보고
#
# 사용법:
#   ./scripts/validate-tasks.sh [tasks.md 경로]   # 기본: specs/*/tasks.md 또는 tasks.md
#
# 종료 코드:
#   0 — 오류 없음
#   1 — 필수 필드 누락 태스크 존재

set -euo pipefail

# python3 필수
if ! command -v python3 &>/dev/null; then
  echo "validate-tasks: python3 not found" >&2
  exit 0
fi

# 검증 대상 파일 결정
if [ -n "${1:-}" ] && [ -f "$1" ]; then
  TASKS_FILE="$1"
elif [ -f "tasks.md" ]; then
  TASKS_FILE="tasks.md"
else
  # specs/**/tasks.md 탐색
  TASKS_FILE=$(find specs -name "tasks.md" 2>/dev/null | head -1 || echo "")
fi

if [ -z "$TASKS_FILE" ] || [ ! -f "$TASKS_FILE" ]; then
  echo "validate-tasks: tasks.md 파일을 찾을 수 없습니다." >&2
  echo "  경로 지정: ./scripts/validate-tasks.sh path/to/tasks.md" >&2
  exit 0
fi

echo "validate-tasks: $TASKS_FILE 검증 중..."

python3 - "$TASKS_FILE" <<'PYEOF'
import sys, re

tasks_file = sys.argv[1]

with open(tasks_file, encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines()

errors = []
warnings = []
current_phase = None
current_phase_num = None   # 0, 0.5, 1, 2, ...
current_task = None
current_task_line = 0
task_fields = {}

def is_phase_0(num):
    return num is not None and float(num) == 0.0

def check_task(task_id, phase_num, fields, line_no):
    """태스크 필드 검증. errors/warnings 리스트에 추가."""
    if is_phase_0(phase_num):
        # Phase 0: status만 필요
        if 'status' not in fields:
            errors.append(f"  L{line_no} [{task_id}] Phase 0 태스크에 **status** 필드 없음")
        return

    # Phase 0.5 이상: required = status, read, done
    required = ['status', 'read', 'done']
    for req in required:
        if req not in fields:
            errors.append(f"  L{line_no} [{task_id}] 필수 필드 없음: **{req}**")

    # write 없으면 경고 (skill로 대체 가능하므로 error 아님)
    if 'write' not in fields and 'skill' not in fields:
        warnings.append(f"  L{line_no} [{task_id}] write/skill 필드 없음 — read-only 태스크인지 확인")

    # done 값 기본 검증 (done이 있을 때만)
    if 'done' in fields:
        done_val = fields['done'].strip()
        if not done_val or done_val in ['-', '—', '{검증 명령}']:
            errors.append(f"  L{line_no} [{task_id}] **done** 필드가 비어 있거나 플레이스홀더입니다")

    # read 값 기본 검증
    if 'read' in fields:
        read_val = fields['read'].strip()
        if not read_val or read_val in ['-', '—', '{입력 파일}']:
            errors.append(f"  L{line_no} [{task_id}] **read** 필드가 비어 있거나 플레이스홀더입니다")

# Phase 감지 패턴
phase_header = re.compile(r'^##\s+Phase\s+([\d.]+)', re.IGNORECASE)
# 태스크 감지 패턴: ### T001: ... 또는 ### T1-001: ...
task_header = re.compile(r'^###\s+(T[\d\-]+)\s*:')
# 필드 패턴: **field**: value
field_line = re.compile(r'^\*\*([\w\-]+)\*\*\s*:\s*(.*)')

for i, line in enumerate(lines, 1):
    # Phase 헤더 감지
    pm = phase_header.match(line)
    if pm:
        # 이전 태스크 검증
        if current_task:
            check_task(current_task, current_phase_num, task_fields, current_task_line)
            current_task = None
            task_fields = {}
        current_phase = line.strip()
        try:
            current_phase_num = float(pm.group(1))
        except ValueError:
            current_phase_num = None
        continue

    # 태스크 헤더 감지
    tm = task_header.match(line)
    if tm:
        # 이전 태스크 검증
        if current_task:
            check_task(current_task, current_phase_num, task_fields, current_task_line)
        current_task = tm.group(1)
        current_task_line = i
        task_fields = {}
        continue

    # 필드 라인 감지
    if current_task:
        fm = field_line.match(line)
        if fm:
            field_name = fm.group(1).lower()
            field_val = fm.group(2).strip()
            task_fields[field_name] = field_val

# 마지막 태스크 검증
if current_task:
    check_task(current_task, current_phase_num, task_fields, current_task_line)

# 결과 출력
total_tasks = 0
# 태스크 수 계산
for line in lines:
    if task_header.match(line):
        total_tasks += 1

if not errors and not warnings:
    print(f"✅ 검증 통과 — 태스크 {total_tasks}개, 오류 없음")
    sys.exit(0)

if warnings:
    print(f"⚠️  경고 {len(warnings)}건:")
    for w in warnings:
        print(w)

if errors:
    print(f"❌ 오류 {len(errors)}건 (필수 필드 누락):")
    for e in errors:
        print(e)
    print(f"\n총 {total_tasks}개 태스크 중 {len(errors)}건 오류 — run-phase 전에 수정하세요.")
    sys.exit(1)
else:
    print(f"총 {total_tasks}개 태스크 검증 완료 (경고 {len(warnings)}건)")
    sys.exit(0)
PYEOF
