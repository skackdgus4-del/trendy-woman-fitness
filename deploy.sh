#!/usr/bin/env bash
# Vercel REST API 로 정적 사이트 배포 (Node/CLI 없이 curl 만 사용)
# 사용법: VERCEL_TOKEN=xxxx bash deploy.sh
# 폴더 안의 index.html 과 이미지/자원 파일(logo.png 등)을 함께 올립니다.
set -euo pipefail
cd "$(dirname "$0")"

: "${VERCEL_TOKEN:?VERCEL_TOKEN 환경변수가 필요합니다}"
PROJECT="${VERCEL_PROJECT:-trendy-woman-fitness}"
API="https://api.vercel.com"
TEAM_QS=""
if [ -n "${VERCEL_TEAM_ID:-}" ]; then TEAM_QS="?teamId=${VERCEL_TEAM_ID}"; fi

# 업로드 대상: html/이미지/폰트/css/js (deploy.sh, *.json 제외)
mapfile -t FILES < <(find . -maxdepth 2 -type f \
  \( -iname '*.html' -o -iname '*.css' -o -iname '*.js' \
     -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
     -o -iname '*.webp' -o -iname '*.svg' -o -iname '*.ico' \
     -o -iname '*.woff' -o -iname '*.woff2' \) \
  | sed 's|^\./||' | sort)

if [ ${#FILES[@]} -eq 0 ]; then echo "업로드할 파일이 없습니다"; exit 1; fi

ENTRIES=""
for f in "${FILES[@]}"; do
  SHA=$(sha1sum "$f" | cut -d' ' -f1)
  SIZE=$(stat -c%s "$f")
  echo "업로드: $f  (${SIZE}B)"
  curl -sS -X POST "$API/v2/files${TEAM_QS}" \
    -H "Authorization: Bearer $VERCEL_TOKEN" \
    -H "x-vercel-digest: $SHA" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$f" > /dev/null
  [ -n "$ENTRIES" ] && ENTRIES="$ENTRIES,"
  ENTRIES="$ENTRIES{\"file\":\"$f\",\"sha\":\"$SHA\",\"size\":$SIZE}"
done

echo "배포 생성 중..."
cat > payload.json <<JSON
{
  "name": "$PROJECT",
  "target": "production",
  "files": [$ENTRIES],
  "projectSettings": { "framework": null }
}
JSON

curl -sS -X POST "$API/v13/deployments${TEAM_QS}" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  --data @payload.json > deploy.json

grep -o '"url":"[^"]*"' deploy.json | head -1 | sed 's/"url":"/배포 URL: https:\/\//;s/"$//' || cat deploy.json
