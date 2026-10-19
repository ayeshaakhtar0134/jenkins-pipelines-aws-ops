#!/usr/bin/env bash
# Tests for cleanup-rds-snapshots.sh using a fake snapshot list (no AWS needed).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${here}/../scripts/cleanup-rds-snapshots.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

days_ago() { date -u -d "-$1 days" +%Y-%m-%dT%H:%M:%S.000Z; }

cat > "$tmp/snapshots.json" <<JSON
{"DBClusterSnapshots": [
  {"DBClusterSnapshotIdentifier": "a-1", "DBClusterIdentifier": "a", "Status": "available", "SnapshotCreateTime": "$(days_ago 1)"},
  {"DBClusterSnapshotIdentifier": "a-30", "DBClusterIdentifier": "a", "Status": "available", "SnapshotCreateTime": "$(days_ago 30)"},
  {"DBClusterSnapshotIdentifier": "a-40", "DBClusterIdentifier": "a", "Status": "available", "SnapshotCreateTime": "$(days_ago 40)"},
  {"DBClusterSnapshotIdentifier": "a-50", "DBClusterIdentifier": "a", "Status": "available", "SnapshotCreateTime": "$(days_ago 50)"},
  {"DBClusterSnapshotIdentifier": "b-90", "DBClusterIdentifier": "b", "Status": "available", "SnapshotCreateTime": "$(days_ago 90)"},
  {"DBClusterSnapshotIdentifier": "a-60-creating", "DBClusterIdentifier": "a", "Status": "creating", "SnapshotCreateTime": "$(days_ago 60)"}
]}
JSON

fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"; echo "  expected: $expected"; echo "  actual:   $actual"; fail=1
  fi
}

SNAPSHOTS_JSON="$tmp/snapshots.json" "$script" --retention-days 14 --keep-latest 2 --output "$tmp/out.txt" >/dev/null
check "keeps newest 2 per cluster, deletes older than 14 days" "a-40 a-50" "$(sort "$tmp/out.txt" | xargs)"

SNAPSHOTS_JSON="$tmp/snapshots.json" "$script" --retention-days 14 --keep-latest 0 --output "$tmp/out.txt" >/dev/null
check "keep-latest 0 removes every old snapshot" "a-30 a-40 a-50 b-90" "$(sort "$tmp/out.txt" | xargs)"

SNAPSHOTS_JSON="$tmp/snapshots.json" "$script" --retention-days 365 --keep-latest 0 --output "$tmp/out.txt" >/dev/null
check "nothing older than retention" "" "$(xargs < "$tmp/out.txt")"

if "$script" --retention-days abc >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "rejects non-numeric retention" "1" "$rc"

exit "$fail"
