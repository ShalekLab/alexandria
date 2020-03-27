#!/bin/bash
set -euo pipefail
mkdir -p scripts/
find ../../scripts/ -maxdepth 1 -type f -execdir cp ./{} ../Docker/alexandria/scripts/ ";"
docker build -t shaleklab/alexandria:dev . \
&& docker push shaleklab/alexandria:dev
#trash scripts/