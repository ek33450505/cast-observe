#!/usr/bin/env bats

REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  command -v sqlite3 || skip "sqlite3 not found"
  export DB="$(mktemp).db"
  export CAST_DB_PATH="$DB"
}

teardown() {
  rm -f "$DB"
}

@test "observe-db-init.sh creates cast.db" {
  run bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB"
  [ $status -eq 0 ]
  [ -f "$DB" ]
}

@test "sessions table exists" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run sqlite3 "$DB" ".tables"
  [ $status -eq 0 ]
  [[ "$output" == *"sessions"* ]]
}

@test "agent_runs table exists" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run sqlite3 "$DB" ".tables"
  [ $status -eq 0 ]
  [[ "$output" == *"agent_runs"* ]]
}

@test "budgets table exists" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run sqlite3 "$DB" ".tables"
  [ $status -eq 0 ]
  [[ "$output" == *"budgets"* ]]
}

@test "routing_events table exists" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run sqlite3 "$DB" ".tables"
  [ $status -eq 0 ]
  [[ "$output" == *"routing_events"* ]]
}

@test "sessions has id column" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run sqlite3 "$DB" "PRAGMA table_info(sessions)"
  [ $status -eq 0 ]
  [[ "$output" == *"id"* ]]
}

@test "sessions has total_cost_usd column" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run sqlite3 "$DB" "PRAGMA table_info(sessions)"
  [ $status -eq 0 ]
  [[ "$output" == *"total_cost_usd"* ]]
}

@test "db init is idempotent" {
  bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB" >/dev/null 2>&1
  run bash "$REPO_DIR/scripts/observe-db-init.sh" --db "$DB"
  [ $status -eq 0 ]
  run sqlite3 "$DB" ".tables"
  [[ "$output" == *"sessions"* ]]
}
