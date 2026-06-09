#!/bin/bash
# Run one rPPG-Toolbox experiment from a config file, logging into experiments/<exp_id>/.
# Usage: bash run_one.sh <exp_id> <abs_config_path>
set -uo pipefail

EXP_ID="$1"
CONFIG="$2"
ROOT="/home/lsg/rPPG"
TOOLBOX="$ROOT/external/rPPG-Toolbox"
EXPDIR="$ROOT/experiments/$EXP_ID"

mkdir -p "$EXPDIR"
cp "$CONFIG" "$EXPDIR/config.yaml"

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rppg
export MPLBACKEND=Agg        # headless-safe matplotlib (avoid Qt backend on a no-display server)

# environment provenance
{
  echo "exp_id: $EXP_ID"
  echo "config: $CONFIG"
  echo "date: $(date -Iseconds)"
  echo "python: $(python --version 2>&1)"
  echo "torch: $(python -c 'import torch;print(torch.__version__, torch.version.cuda)')"
  echo "toolbox_commit: $(cd "$TOOLBOX" && git rev-parse HEAD)"
} > "$EXPDIR/environment.txt"

echo "=== Running $EXP_ID ==="
cd "$TOOLBOX"
# stdbuf to keep the metric prints flowing into the log in real time
stdbuf -oL -eL python main.py --config_file "$CONFIG" 2>&1 | tee "$EXPDIR/run.log"
echo "=== Finished $EXP_ID (exit ${PIPESTATUS[0]}) ==="
