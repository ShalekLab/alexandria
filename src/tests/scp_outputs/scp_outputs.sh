#!/bin/bash
set -euo pipefail
cd /Users/jggatter/Desktop/Alexandria/alexandria_repository/src
if [ -d ./tests/scp_outputs/outputs ]; then rm -r ./tests/scp_outputs/outputs; fi
mkdir -p ./tests/scp_outputs/outputs/
python scp_outputs.py \
	-i /Users/jggatter/Desktop/Alexandria/alexandria_repository/src/tests/scp_outputs/inputs/default_dir.csv \
	-s /Users/jggatter/Desktop/Alexandria/alexandria_repository/src/tests/scp_outputs/inputs/scp_outputs.txt \
	-c /Users/jggatter/Desktop/Alexandria/alexandria_repository/src/tests/scp_outputs/inputs/scp.scp.expr.txt \
	-m /Users/jggatter/Desktop/Alexandria/alexandria_repository/src/tests/scp_outputs/inputs/metadata_type_map.tsv \
	-o /Users/jggatter/Desktop/Alexandria/alexandria_repository/src/tests/scp_outputs/outputs/
#head /Users/jggatter/Desktop/Alexandria/alexandria_repository/src/tests/scp_outputs/outputs/alexandria_metadata.txt