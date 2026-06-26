#!/bin/bash
# Full 42-subject UBFC benchmark, unattended.
# Mirrors the smoke test (E01-E06) but on the COMPLETE UBFC set (E11-E16):
#   E11 unsupervised (7 methods, CPU) + E12-E16 PURE->UBFC neural inference (GPU).
# Launched detached (setsid+nohup) so it survives SSH logout and the Claude session.
#
# Cache (~tens of GB) goes to the project's data dir on the big drive
# (/media/amdin/Drive1/rppg_data/processed) because /home has <25G free.
# All code/configs/logs/results stay under /home/lsg/rPPG.
set -uo pipefail

ROOT=/home/lsg/rPPG
export PATH="/home/lsg/miniconda3/bin:/home/lsg/miniconda3/condabin:$PATH"   # make conda findable when detached
cd "$ROOT"
mkdir -p logs
rm -f logs/full_ubfc.DONE

STATUS="$ROOT/logs/full_ubfc_STATUS.txt"
: > "$STATUS"
log() { echo "[$(date -Iseconds)] $*" | tee -a "$STATUS"; }

disk() { echo "/home=$(df -h /home | awk 'NR==2{print $4}') free, bigdrive=$(df -h /media/amdin/Drive1 | awk 'NR==2{print $4}') free"; }

log "FULL UBFC run started (pid $$, host $(hostname))"
log "disk: $(disk)"

# NOTE: run_one.sh does `cd $TOOLBOX`, so the config path MUST be absolute.
run() {
  local exp_id="$1" cfg="$2" tag="$3"
  log "START $exp_id  -> logs/${tag}.log"
  bash scripts/repro/run_one.sh "$exp_id" "$cfg" > "logs/${tag}.log" 2>&1
  # run_one.sh always exits 0, so judge success from the run log itself.
  if grep -q "Traceback (most recent call last)" "$ROOT/experiments/$exp_id/run.log" 2>/dev/null; then
    log "END   $exp_id  (FAILED - see experiments/$exp_id/run.log) | $(disk)"
  else
    log "END   $exp_id  (ok) | $(disk)"
  fi
}

run E11_unsup_UBFCfull               "$ROOT/configs/repro/UBFC_full_UNSUPERVISED.yaml"  E11_unsup
run E12_PURE2UBFC_physnet_full       "$ROOT/configs/repro/UBFC_full_PHYSNET.yaml"       E12_physnet
run E13_PURE2UBFC_tscan_full         "$ROOT/configs/repro/UBFC_full_TSCAN.yaml"         E13_tscan
run E14_PURE2UBFC_deepphys_full      "$ROOT/configs/repro/UBFC_full_DEEPPHYS.yaml"      E14_deepphys
run E15_PURE2UBFC_efficientphys_full "$ROOT/configs/repro/UBFC_full_EFFICIENTPHYS.yaml" E15_efficientphys
run E16_PURE2UBFC_physformer_full    "$ROOT/configs/repro/UBFC_full_PHYSFORMER.yaml"    E16_physformer

log "Building summary..."
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rppg
python scripts/repro/build_full_summary.py 2>&1 | tee -a "$STATUS"

log "disk: $(disk)"
log "ALL FULL UBFC DONE"
touch "$ROOT/logs/full_ubfc.DONE"
