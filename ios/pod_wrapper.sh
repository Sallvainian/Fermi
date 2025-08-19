#!/bin/bash
# Wrapper script to ensure correct CocoaPods is used
export PATH="/opt/homebrew/bin:$PATH"
exec /opt/homebrew/bin/pod "$@"