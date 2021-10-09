#!/bin/sh

FORMATTER_DIR="$(dirname $0)"
GIT_HOOK_DIR="$FORMATTER_DIR/../.git/hooks"
cp $FORMATTER_DIR/pre-commit $GIT_HOOK_DIR/pre-commit
chmod +x $GIT_HOOK_DIR/pre-commit
echo "pre-commit hook installed in $GIT_HOOK_DIR/pre-commit."
