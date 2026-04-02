#!/usr/bin/env bats

REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  export REAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  export CAST_DB_PATH="$HOME/.claude/cast.db"
  export PATH="$REPO_DIR/bin:$PATH"
}

teardown() {
  rm -rf "$HOME"
  export HOME="$REAL_HOME"
}

@test "install.sh exits 0" {
  run bash "$REPO_DIR/install.sh"
  [ $status -eq 0 ]
}

@test "install is idempotent" {
  run bash "$REPO_DIR/install.sh"
  [ $status -eq 0 ]
  run bash "$REPO_DIR/install.sh"
  [ $status -eq 0 ]
}

@test "scripts are installed" {
  bash "$REPO_DIR/install.sh" >/dev/null 2>&1
  [ -f "$HOME/.claude/scripts/observe-db-init.sh" ]
}

@test "database is created" {
  bash "$REPO_DIR/install.sh" >/dev/null 2>&1
  [ -f "$HOME/.claude/cast.db" ]
}

@test "cast-observe --version works after install" {
  command -v sqlite3 || skip "sqlite3 not found"
  bash "$REPO_DIR/install.sh" >/dev/null 2>&1
  run cast-observe --version
  [ $status -eq 0 ]
  [[ "$output" == *"v"* ]]
}
