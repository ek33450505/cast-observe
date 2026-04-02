#!/usr/bin/env bats

REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup_file() {
  command -v sqlite3 || skip "sqlite3 not found"
  export SHARED_HOME="$(mktemp -d)"
  export CAST_DB_PATH="$SHARED_HOME/.claude/cast.db"
  HOME="$SHARED_HOME" CAST_DB_PATH="$CAST_DB_PATH" bash "$REPO_DIR/install.sh" >/dev/null 2>&1
}

teardown_file() {
  rm -rf "$SHARED_HOME"
}

setup() {
  command -v sqlite3 || skip "sqlite3 not found"
  export HOME="$SHARED_HOME"
  export CAST_DB_PATH="$HOME/.claude/cast.db"
  export PATH="$REPO_DIR/bin:$PATH"
}

@test "--version exits 0 and shows version string" {
  run cast-observe --version
  [ $status -eq 0 ]
  [[ "$output" == *"cast-observe v"* ]]
}

@test "--help exits 0" {
  run cast-observe --help
  [ $status -eq 0 ]
}

@test "db path exits 0 and ends in .db" {
  run cast-observe db path
  [ $status -eq 0 ]
  [[ "$output" == *".db" ]]
}

@test "db size exits 0" {
  run cast-observe db size
  [ $status -eq 0 ]
}

@test "status exits 0" {
  run cast-observe status
  [ $status -eq 0 ]
}

@test "budget --week exits 0" {
  run cast-observe budget --week
  [ $status -eq 0 ]
}

@test "sessions --limit 3 exits 0" {
  run cast-observe sessions --limit 3
  [ $status -eq 0 ]
}

@test "db query SELECT 1 returns 1" {
  run cast-observe db query "SELECT 1"
  [ $status -eq 0 ]
  [[ "$output" == *"1"* ]]
}
