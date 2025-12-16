#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-start}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$ROOT_DIR/pokemon-showdown"
CLIENT_DIR="$ROOT_DIR/pokemon-showdown-client/play.pokemonshowdown.com"
LOG_DIR="$ROOT_DIR/.local-ps-logs"
SERVER_LOG="$LOG_DIR/server.log"
CLIENT_LOG="$LOG_DIR/client.log"
SERVER_PID_FILE="$LOG_DIR/server.pid"
CLIENT_PID_FILE="$LOG_DIR/client.pid"
SERVER_PORT="${SERVER_PORT:-8100}"
CLIENT_PORT="${CLIENT_PORT:-8080}"

mkdir -p "$LOG_DIR"

ensure_repo() {
	if [[ ! -d "$SERVER_DIR" || ! -d "$CLIENT_DIR" ]]; then
		echo "ERROR: Expected pokemon-showdown and pokemon-showdown-client under $ROOT_DIR" >&2
		exit 1
	fi
}

is_running() {
	local pid_file=$1
	if [[ -f "$pid_file" ]]; then
		local pid
		pid="$(<"$pid_file")"
		if kill -0 "$pid" 2>/dev/null; then
			echo "$pid"
			return 0
		fi
	fi
	return 1
}

stop_proc() {
	local name=$1
	local pid_file=$2
	if pid=$(is_running "$pid_file"); then
		echo "Stopping $name (PID $pid)..."
		kill "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
	fi
	rm -f "$pid_file"
}

start_server() {
	stop_proc "server" "$SERVER_PID_FILE"
	echo "Starting Pokémon Showdown server on port $SERVER_PORT..."
	(
		cd "$SERVER_DIR"
		PORT="$SERVER_PORT" nohup ./pokemon-showdown >"$SERVER_LOG" 2>&1 &
		echo $! >"$SERVER_PID_FILE"
	)
	sleep 1
	if ! pid=$(is_running "$SERVER_PID_FILE"); then
		echo "Server failed to start. Check $SERVER_LOG" >&2
		exit 1
	fi
}

start_client() {
	stop_proc "client" "$CLIENT_PID_FILE"
	echo "Starting client web server on port $CLIENT_PORT..."
	(
		cd "$CLIENT_DIR"
		nohup npx http-server -p "$CLIENT_PORT" >"$CLIENT_LOG" 2>&1 &
		echo $! >"$CLIENT_PID_FILE"
	)
	sleep 1
	if ! pid=$(is_running "$CLIENT_PID_FILE"); then
		echo "Client failed to start. Check $CLIENT_LOG" >&2
		exit 1
	fi
}

status() {
	if pid=$(is_running "$SERVER_PID_FILE"); then
		echo "Server running (PID $pid) - log: $SERVER_LOG"
	else
		echo "Server not running"
	fi
	if pid=$(is_running "$CLIENT_PID_FILE"); then
		echo "Client running (PID $pid) - log: $CLIENT_LOG"
	else
		echo "Client not running"
	fi
}

ensure_repo

case "$ACTION" in
	start)
		start_server
		start_client
		status
		echo
		echo "Client URL: http://localhost:$CLIENT_PORT/testclient.html?~~localhost:$SERVER_PORT"
		;;
	stop)
		stop_proc "client" "$CLIENT_PID_FILE"
		stop_proc "server" "$SERVER_PID_FILE"
		status
		;;
	status)
		status
		;;
	restart)
		"$0" stop
		"$0" start
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status}" >&2
		exit 1
		;;
esac
