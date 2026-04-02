#!/usr/bin/env bats

REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPTS="$REPO_DIR/scripts"

setup() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    skip "sqlite3 not found"
  fi
  export REAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  export CAST_DB_PATH="$HOME/cast.db"
  CAST_DB_PATH="$CAST_DB_PATH" bash "$SCRIPTS/observe-db-init.sh" >/dev/null 2>&1 || true
}

teardown() {
  rm -rf "$HOME"
  export HOME="$REAL_HOME"
}

@test "observe-session-start.sh exits 0 with empty stdin" {
  run bash -c "echo '' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-session-start.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-session-start.sh exits 0 with valid JSON" {
  run bash -c "echo '{\"session_id\":\"test-123\",\"hook_event_name\":\"SessionStart\",\"cwd\":\"/tmp\"}' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-session-start.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-cost-tracker.sh exits 0 with empty stdin" {
  run bash -c "echo '' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-cost-tracker.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-cost-tracker.sh exits 0 with PostToolUse JSON" {
  local json
  json='{"session_id":"test","hook_event_name":"PostToolUse","tool_name":"Bash","tool_response":{"type":"tool_result","total_cost_usd":0.001,"usage":{"input_tokens":10,"output_tokens":20}}}'
  run bash -c "echo '$json' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-cost-tracker.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-subagent-stop.sh exits 0 with empty stdin" {
  run bash -c "echo '' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-subagent-stop.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-subagent-stop.sh exits 0 with SubagentStop JSON" {
  local json
  json='{"session_id":"test","agent_type":"general-purpose","last_assistant_message":"done","stop_reason":"end_turn"}'
  run bash -c "echo '$json' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-subagent-stop.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-session-end.sh exits 0 with empty stdin" {
  run bash -c "echo '' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-session-end.sh'"
  [ "$status" -eq 0 ]
}

@test "observe-budget-alert.sh exits 0 with empty stdin" {
  run bash -c "echo '' | CAST_DB_PATH='$CAST_DB_PATH' bash '$SCRIPTS/observe-budget-alert.sh'"
  [ "$status" -eq 0 ]
}
