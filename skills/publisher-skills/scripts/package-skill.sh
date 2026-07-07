#!/usr/bin/env bash
#
# 把 skills/publisher-skill/ 打包成 publisher-skill.zip，并同步到下载目录。
#
# 版本号单一源：skills/publisher-skill/VERSION（只有这一处需要手改）。
# 打包前会先把 VERSION 里的版本号同步写入：
#   - SKILL.md      frontmatter 的 version
#   - SKILL-zh.md   frontmatter 的 version
#   - backend application.yml 的 app.skill-version
# 于是发版流程是：改 VERSION -> 跑本脚本 -> 各处全部生效。
#
# 输出（两处都更新，保持前后端一致）：
#   - backend/src/main/resources/static/downloads/publisher-skill.zip
#   - frontend/public/downloads/publisher-skill.zip
#
# 用法：
#   bash skills/publisher-skill/scripts/package-skill.sh
#   bash skills/publisher-skill/scripts/package-skill.sh --check   # 只校验/同步，不打包
#
# 依赖：优先用 `zip`（Linux/macOS/CI）；缺少时回退到 Windows PowerShell 的
# Compress-Archive。两条路径产出的 zip 顶层都是 publisher-skill/ 目录。

set -euo pipefail

# 仓库根目录 = 本脚本所在目录往上三层（scripts -> publisher-skill -> skills -> repo）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_PARENT="$(cd "$SKILL_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILLS_PARENT/.." && pwd)"

SKILL_NAME="publisher-skill"
ZIP_NAME="$SKILL_NAME.zip"

VERSION_FILE="$SKILL_DIR/VERSION"
BACKEND_OUT="$REPO_ROOT/backend/src/main/resources/static/downloads/$ZIP_NAME"
FRONTEND_OUT="$REPO_ROOT/frontend/public/downloads/$ZIP_NAME"
APP_YML="$REPO_ROOT/backend/src/main/resources/application.yml"

# 校验版本号形如 X.Y.Z（语义化版本三段）
validate_semver() {
  local v="$1"
  if ! [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: VERSION 内容 '$v' 不是合法的 X.Y.Z 版本号" >&2
    exit 1
  fi
}

# 把 frontmatter（第一段 --- ... ---）里的 version 改成目标值；缺失则在 --- 内补一行。
# 用 awk 重写整文件，确保只改 frontmatter 区、不误伤正文里的 "version" 字样。
sync_frontmatter_version() {
  local file="$1" ver="$2" tmp
  tmp="$(mktemp)"
  awk -v ver="$ver" '
    NR==1 && $0=="---" { print; in_fm=1; seen=0; next }
    in_fm && $0=="---" {
      if (!seen) print "version: " ver
      print; in_fm=0; next
    }
    in_fm && $1=="version:" { print "version: " ver; seen=1; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# 把 application.yml 中 app: 块下的 skill-version 改成目标值（保留原有缩进）。
sync_yml_skill_version() {
  local file="$1" ver="$2" tmp
  tmp="$(mktemp)"
  awk -v ver="$ver" '
    /^app:/ { in_app=1; print; next }
    in_app && /^[^[:space:]]/ { in_app=0 }
    in_app && $1=="skill-version:" {
      match($0, /^[[:space:]]*/); indent=substr($0, 1, RLENGTH)
      print indent "skill-version: " ver; next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# 读取 application.yml 当前 app.skill-version（用于同步后回读校验）
read_yml_skill_version() {
  awk '
    /^app:/ { in_app=1; next }
    in_app && /^[^[:space:]]/ { in_app=0 }
    in_app && $1=="skill-version:" { print $2; exit }
  ' "$1" | tr -d "\r\"'"
}

# 读取 frontmatter version（用于同步后回读校验）
read_frontmatter_version() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm && $1=="version:" { print $2; exit }
  ' "$1" | tr -d "\r\"'"
}

# ---- 读取单一源 ----
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: 未找到版本号单一源 $VERSION_FILE" >&2
  exit 1
fi
SKILL_VERSION="$(tr -d " \t\r\n\"'" < "$VERSION_FILE")"
validate_semver "$SKILL_VERSION"

echo "==> 单一源 VERSION = $SKILL_VERSION，同步到各处"
sync_frontmatter_version "$SKILL_DIR/SKILL.md" "$SKILL_VERSION"
sync_frontmatter_version "$SKILL_DIR/SKILL-zh.md" "$SKILL_VERSION"
echo "    SKILL.md / SKILL-zh.md frontmatter ✓"

if [[ -f "$APP_YML" ]]; then
  if [[ -n "$(read_yml_skill_version "$APP_YML")" ]]; then
    sync_yml_skill_version "$APP_YML" "$SKILL_VERSION"
    AFTER_YML="$(read_yml_skill_version "$APP_YML")"
    if [[ "$AFTER_YML" != "$SKILL_VERSION" ]]; then
      echo "ERROR: application.yml 同步后回读为 '$AFTER_YML'，与 $SKILL_VERSION 不一致" >&2
      exit 1
    fi
    echo "    application.yml app.skill-version ✓"
  else
    echo "    WARN: application.yml 未找到 app.skill-version 行，跳过（请确认是否遗漏）" >&2
  fi
else
  echo "    (未找到 application.yml，跳过后端版本同步)"
fi

# 回读 frontmatter 确认同步成功
AFTER_EN="$(read_frontmatter_version "$SKILL_DIR/SKILL.md")"
AFTER_ZH="$(read_frontmatter_version "$SKILL_DIR/SKILL-zh.md")"
if [[ "$AFTER_EN" != "$SKILL_VERSION" || "$AFTER_ZH" != "$SKILL_VERSION" ]]; then
  echo "ERROR: frontmatter 同步失败 (SKILL.md=$AFTER_EN, SKILL-zh.md=$AFTER_ZH)" >&2
  exit 1
fi

# --check：只同步/校验，不打包
if [[ "${1:-}" == "--check" ]]; then
  echo "==> --check 完成：版本号已同步为 $SKILL_VERSION（未打包）。"
  exit 0
fi

# 临时输出，成功后再覆盖到目标，避免打包失败留下半成品
TMP_ZIP="$(mktemp -u).zip"

# 暂存目录：把要打包的内容复制进 <stage>/publisher-skill/，排除 scripts 自身。
# 这样既能精确控制 zip 内容、保证顶层是 publisher-skill/，又避开“正在运行的脚本
# 文件被占用导致压缩失败”的问题。
STAGE_DIR="$(mktemp -d)"
STAGE_SKILL="$STAGE_DIR/$SKILL_NAME"
mkdir -p "$STAGE_SKILL"

# 复制除 scripts 外的全部内容（含 .cursor 等隐藏目录）
( cd "$SKILL_DIR" && for entry in * .[!.]*; do
    [[ -e "$entry" ]] || continue
    [[ "$entry" == "scripts" ]] && continue
    cp -R "$entry" "$STAGE_SKILL/"
  done )

echo "==> 打包 $SKILL_NAME (version $SKILL_VERSION)"
if command -v zip >/dev/null 2>&1; then
  ( cd "$STAGE_DIR" && zip -r -q "$TMP_ZIP" "$SKILL_NAME" )
else
  echo "    未找到 zip，改用 PowerShell Compress-Archive"
  win_path() { cygpath -w "$1" 2>/dev/null || echo "$1"; }
  STAGE_WIN="$(win_path "$STAGE_SKILL")"
  TMP_WIN="$(win_path "$TMP_ZIP")"
  powershell.exe -NoProfile -NonInteractive -Command \
    "Compress-Archive -Path '$STAGE_WIN' -DestinationPath '$TMP_WIN' -Force" \
    >/dev/null
fi

rm -rf "$STAGE_DIR"

if [[ ! -f "$TMP_ZIP" ]]; then
  echo "ERROR: 打包失败，未生成 zip" >&2
  exit 1
fi

echo "==> 写入下载目录"
for OUT in "$BACKEND_OUT" "$FRONTEND_OUT"; do
  mkdir -p "$(dirname "$OUT")"
  cp -f "$TMP_ZIP" "$OUT"
  echo "    $OUT"
done

rm -f "$TMP_ZIP"

echo "==> 完成。已生成 $ZIP_NAME (version $SKILL_VERSION) 并同步到 backend / frontend 下载目录。"
echo "    提醒：若后端正在运行，static 资源需重启或重新构建才会对外生效。"
