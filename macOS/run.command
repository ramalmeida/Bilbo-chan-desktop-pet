#!/bin/zsh
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BIN="$ROOT_DIR/Bilbo-Chan.app/Contents/MacOS/bilbo-chan"

if [[ ! -x "$APP_BIN" ]]; then
  /usr/bin/osascript -e 'display alert "Bilbo-Chan nao encontrou o executavel" message "Recompile o app ou verifique a pasta Bilbo-Chan.app."'
  exit 1
fi

exec "$APP_BIN" "$@"
