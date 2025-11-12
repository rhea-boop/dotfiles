#!/bin/bash
LOG_FILE="/home/rhea/.gemini/tmp/a7d4e8491609c69b77be11bbac40ff1c6931b675c0ad0a35de821ca8d6f5c960/noctalia_matugen_call.log"
echo "Matugen call: $@" >> "$LOG_FILE"
# Also capture the config file content if --config is used
i=1
for arg in "$@"; do
    if [[ "$arg" == "--config" ]]; then
        # Get the next argument, which should be the config file path
        config_file="${!i}"
        echo "Matugen config file: $config_file" >> "$LOG_FILE"
        cat "$config_file" >> "$LOG_FILE"
        break
    fi
    ((i++))
done
