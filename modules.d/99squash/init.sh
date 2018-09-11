#!/bin/sh
/squash/setup-squash.sh

exec /init.stock

echo "Something went wrong when trying to start origin init executable"
exit 1
