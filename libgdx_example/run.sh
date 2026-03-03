#!/bin/bash
set -euo pipefail

mainClass="${1:-com.project.Main}"
jvmArgs=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    jvmArgs="-XstartOnFirstThread"
fi

mvn -PrunMain -Dexec.mainClass="$mainClass" -Dexec.jvmArgs="$jvmArgs" clean compile exec:exec
