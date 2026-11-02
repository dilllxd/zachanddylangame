#!/usr/bin/env bash
# Requires Godot 4.7.1 with matching Web export templates, rsync, and SSH access.
# Always exports outside the Backstitch project so generated files never sync.
set -euo pipefail
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$PROJECT/.godot_editor/Godot_v4.7.1-stable_linux.x86_64}"
DEPLOY_HOST="${DEPLOY_HOST:-debian@40.160.53.64}"
DEPLOY_DIR="${DEPLOY_DIR:-/srv/fishingidle}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/kat_vps}"
[[ -x "$GODOT" ]] || { echo "Set GODOT to your Godot 4.7.1 executable" >&2; exit 1; }
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/fishing-web.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
"$GODOT" --headless --path "$PROJECT" --import
"$GODOT" --headless --path "$PROJECT" --export-release Web "$BUILD/index.html"
# Every asset is revalidated, so deploying never strands players on stale scripts.
rsync -az --chmod=D755,F644 --delete -e "ssh -i $SSH_KEY" "$BUILD/" "$DEPLOY_HOST:$DEPLOY_DIR/www/"
curl --fail --silent --show-error "https://fish.40-160-53-64.sslip.io/health"
printf '\nPublished https://fish.40-160-53-64.sslip.io/\n'
