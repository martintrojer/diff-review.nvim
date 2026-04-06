#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d /tmp/diff-review-tests.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

NVIM_BIN="${NVIM_BIN:-nvim}"
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-diff-review}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-diff-review@example.test}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"

hash_file() {
  sha256sum "$1" | awk '{print $1}' | cut -c1-12
}

run_case() {
  local name="$1"
  shift
  echo "==> $name"
  (
    export NVIM_LOG_FILE="$TMP_ROOT/${name}.nvim.log"
    export DIFF_LEFT="$1"
    export DIFF_RIGHT="$2"
    export DIFF_MODE="$3"
    export DIFF_SIDE="$4"
    export EXPECT_VCS="$5"
    export EXPECT_PATH="$6"
    export EXPECT_PEER_PATH="$7"
    export EXPECT_REV="$8"
    export EXPECT_PEER_REV="$9"
    shift 9
    export DIFF_IGNORE="${1:-}"
    export EXPECT_QF_TEXT="${2:-}"
    export EXPECT_HUNK="${3:-}"
    export USE_PUBLIC="${4:-0}"
    export EXPECT_COMMENT="integration:$name"

    "$NVIM_BIN" --headless -u NONE -i NONE \
      -c 'set shadafile=NONE noswapfile shortmess+=I' \
      -c "set rtp+=$ROOT" \
      -c 'packadd nvim.difftool' \
      -c 'runtime plugin/diff-review.lua' \
      -c "lua local ok, err = pcall(dofile, '$ROOT/tests/assert_case.lua'); if not ok then print(err); vim.cmd('cquit 1') end" \
      -c 'qa!'
  )
}

setup_git_repo() {
  GIT_REPO="$TMP_ROOT/git-repo"
  mkdir -p "$GIT_REPO"
  cd "$GIT_REPO"
  git init -q
  printf 'one\n' > a.txt
  git add a.txt
  git commit -q -m init
  printf 'one\ntwo\n' > a.txt

  GIT_LEFT_FILE="$TMP_ROOT/git-left.txt"
  git show HEAD:a.txt > "$GIT_LEFT_FILE"
  GIT_LEFT_DIR="$TMP_ROOT/git-leftdir"
  mkdir -p "$GIT_LEFT_DIR"
  cp "$GIT_LEFT_FILE" "$GIT_LEFT_DIR/a.txt"

  GIT_HEAD_SHORT="$(git rev-parse --short=12 HEAD)"
  GIT_BASE_BLOB_SHORT="$(git ls-tree HEAD -- a.txt | awk '{print $3}' | cut -c1-12)"
  GIT_WORKTREE_SHORT="$(hash_file a.txt)"
  GIT_REV="WORKTREE $GIT_WORKTREE_SHORT"
  GIT_PEER_REV="HEAD $GIT_HEAD_SHORT blob $GIT_BASE_BLOB_SHORT"
}

setup_jj_repo() {
  JJ_REPO="$TMP_ROOT/jj-repo"
  mkdir -p "$JJ_REPO"
  cd "$JJ_REPO"
  jj git init --quiet
  printf 'one\n' > a.txt
  jj file track a.txt
  jj commit -m init --quiet
  printf 'one\ntwo\n' > a.txt

  JJ_LEFT_FILE="$TMP_ROOT/jj-left.txt"
  jj file show -r @- a.txt > "$JJ_LEFT_FILE"
  JJ_LEFT_DIR="$TMP_ROOT/jj-leftdir"
  mkdir -p "$JJ_LEFT_DIR"
  cp "$JJ_LEFT_FILE" "$JJ_LEFT_DIR/a.txt"

  JJ_AT="$(jj log -r @ -T 'change_id.short() ++ " " ++ commit_id.short()' --no-graph -n 1)"
  JJ_PARENT="$(jj log -r @- -T 'change_id.short() ++ " " ++ commit_id.short()' --no-graph -n 1)"
  JJ_REV="@ $JJ_AT"
  JJ_PEER_REV="@- $JJ_PARENT"
}

setup_hg_repo() {
  HG_REPO="$TMP_ROOT/hg-repo"
  mkdir -p "$HG_REPO"
  cd "$HG_REPO"
  hg init
  printf 'one\n' > a.txt
  hg add a.txt
  hg commit -m init -u test
  printf 'one\ntwo\n' > a.txt

  HG_LEFT_FILE="$TMP_ROOT/hg-left.txt"
  hg cat -r . a.txt > "$HG_LEFT_FILE"
  HG_LEFT_DIR="$TMP_ROOT/hg-leftdir"
  mkdir -p "$HG_LEFT_DIR"
  cp "$HG_LEFT_FILE" "$HG_LEFT_DIR/a.txt"

  HG_WORKTREE_SHORT="$(hash_file a.txt)"
  HG_DOT="$(hg log -r . --template '{rev} {node|short}')"
  HG_FILE_SHORT="$(hg manifest --debug -r . | awk '/  a.txt$/ {print $1}' | cut -c1-12)"
  HG_REV="WORKTREE $HG_WORKTREE_SHORT"
  HG_PEER_REV="$HG_DOT file $HG_FILE_SHORT"
}

setup_git_repo
run_case "git-file-right" "$GIT_LEFT_FILE" "$GIT_REPO/a.txt" "file" "right" "git" "a.txt" "$GIT_LEFT_FILE" "$GIT_REV" "$GIT_PEER_REV" "" "" "@@ -1 +1,2 @@" "1"
run_case "git-file-left" "$GIT_LEFT_FILE" "$GIT_REPO/a.txt" "file" "left" "git" "$GIT_LEFT_FILE" "a.txt" "$GIT_PEER_REV" "$GIT_REV" "" "" "@@ -1 +1,2 @@"
run_case "git-dir-right" "$GIT_LEFT_DIR" "$GIT_REPO" "dir" "right" "git" "a.txt" "a.txt" "$GIT_REV" "$GIT_PEER_REV" ".git" "M" "@@ -1 +1,2 @@"

setup_jj_repo
run_case "jj-file-right" "$JJ_LEFT_FILE" "$JJ_REPO/a.txt" "file" "right" "jj" "a.txt" "$JJ_LEFT_FILE" "$JJ_REV" "$JJ_PEER_REV" "" "" "@@ -1,1 +1,2 @@"
run_case "jj-file-left" "$JJ_LEFT_FILE" "$JJ_REPO/a.txt" "file" "left" "jj" "$JJ_LEFT_FILE" "a.txt" "$JJ_PEER_REV" "$JJ_REV" "" "" "@@ -1,1 +1,2 @@"
run_case "jj-dir-right" "$JJ_LEFT_DIR" "$JJ_REPO" "dir" "right" "jj" "a.txt" "a.txt" "$JJ_REV" "$JJ_PEER_REV" ".git:.jj" "M" "@@ -1,1 +1,2 @@"

setup_hg_repo
run_case "hg-file-right" "$HG_LEFT_FILE" "$HG_REPO/a.txt" "file" "right" "hg" "a.txt" "$HG_LEFT_FILE" "$HG_REV" "$HG_PEER_REV" "" "" "@@ -1,1 +1,2 @@"
run_case "hg-file-left" "$HG_LEFT_FILE" "$HG_REPO/a.txt" "file" "left" "hg" "$HG_LEFT_FILE" "a.txt" "$HG_PEER_REV" "$HG_REV" "" "" "@@ -1,1 +1,2 @@"
run_case "hg-dir-right" "$HG_LEFT_DIR" "$HG_REPO" "dir" "right" "hg" "a.txt" "a.txt" "$HG_REV" "$HG_PEER_REV" ".hg" "M" "@@ -1,1 +1,2 @@"

echo "all integration tests passed"
