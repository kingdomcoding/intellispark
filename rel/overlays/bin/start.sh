#!/bin/sh
set -eu

echo "[release] running migrations..."
/app/bin/intellispark eval 'Intellispark.Release.migrate()'
echo "[release] migrations complete, starting endpoint..."

exec /app/bin/intellispark start
