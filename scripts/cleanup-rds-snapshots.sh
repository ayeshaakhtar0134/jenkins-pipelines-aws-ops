#!/usr/bin/env bash
# Finds (and optionally deletes) manual RDS cluster snapshots older than N days,
# always keeping the newest K per cluster.
#
#   Find:   cleanup-rds-snapshots.sh --retention-days 14 --keep-latest 3 --output candidates.txt
#   Delete: cleanup-rds-snapshots.sh --delete-from candidates.txt
#
# Set SNAPSHOTS_JSON to a file to read snapshots from it instead of AWS (used by tests).
set -euo pipefail

retention_days=14
keep_latest=3
output=""
delete_from=""

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --retention-days) retention_days="$2"; shift 2 ;;
    --keep-latest)    keep_latest="$2"; shift 2 ;;
    --output)         output="$2"; shift 2 ;;
    --delete-from)    delete_from="$2"; shift 2 ;;
    -h|--help)        usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

if [[ -n "$delete_from" ]]; then
  deleted=0
  while IFS= read -r snapshot_id; do
    [[ -z "$snapshot_id" ]] && continue
    echo "Deleting ${snapshot_id}"
    aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier "$snapshot_id" >/dev/null
    deleted=$((deleted + 1))
  done < "$delete_from"
  echo "Deleted ${deleted} snapshot(s)."
  exit 0
fi

if ! [[ "$retention_days" =~ ^[0-9]+$ && "$keep_latest" =~ ^[0-9]+$ ]]; then
  echo "--retention-days and --keep-latest must be whole numbers" >&2
  exit 1
fi

if [[ -n "${SNAPSHOTS_JSON:-}" ]]; then
  snapshots=$(cat "$SNAPSHOTS_JSON")
else
  snapshots=$(aws rds describe-db-cluster-snapshots --snapshot-type manual --output json)
fi

cutoff=$(date -u -d "-${retention_days} days" +%Y-%m-%dT%H:%M:%S)

# Per cluster: sort newest first, skip the newest K, then pick those older than the cutoff.
candidates=$(jq -r --arg cutoff "$cutoff" --argjson keep "$keep_latest" '
  .DBClusterSnapshots
  | map(select(.Status == "available"))
  | group_by(.DBClusterIdentifier)[]
  | sort_by(.SnapshotCreateTime) | reverse
  | .[$keep:][]
  | select(.SnapshotCreateTime[0:19] < $cutoff)
  | .DBClusterSnapshotIdentifier
' <<<"$snapshots")

count=$(grep -c . <<<"$candidates" || true)
echo "Cutoff: ${cutoff} UTC, keeping newest ${keep_latest} per cluster."
echo "${count} snapshot(s) eligible for deletion:"
while IFS= read -r id; do
  [[ -n "$id" ]] && echo "  - ${id}"
done <<<"$candidates"

if [[ -n "$output" ]]; then
  printf '%s\n' "$candidates" | sed '/^$/d' > "$output"
fi
