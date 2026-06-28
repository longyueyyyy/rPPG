#!/bin/bash
# MR-NIRP Car (driving) pilot, unattended. PURE-pretrained cross-dataset inference +
# unsupervised, on BOTH streams (NIR, RGB), over all usable sessions (video + PulseOX GT).
# Detached (setsid) so it survives SSH logout and the Claude session.
#
# NIR is single-channel: only GREEN is valid unsupervised (chrominance degenerates / ICA
# crashes), neural runs RGB-pretrained nets on replicated NIR (heavy domain shift).
# RGB color is NIR-illuminator contaminated -> chrominance unreliable (reported, not hidden).
set -uo pipefail

ROOT=/home/lsg/rPPG
export PATH="/home/lsg/miniconda3/bin:/home/lsg/miniconda3/condabin:$PATH"
cd "$ROOT"
mkdir -p logs
rm -f logs/mrnirp.DONE
bash scripts/mrnirp/install_into_toolbox.sh >/dev/null 2>&1 || true

# scope: all usable sessions (loader requires video+GT); cap frames for a tractable first pilot
export MRNIRP_MAX_FRAMES=4500   # ~150 s/session @30 fps
unset MRNIRP_SUBJECTS MRNIRP_SESSIONS 2>/dev/null || true

STATUS="$ROOT/logs/mrnirp_STATUS.txt"; : > "$STATUS"
log(){ echo "[$(date -Iseconds)] $*" | tee -a "$STATUS"; }
disk(){ echo "/home=$(df -h /home|awk 'NR==2{print $4}') big=$(df -h /media/amdin/Drive1|awk 'NR==2{print $4}')"; }

run(){  # exp_id config tag stream
  local exp_id="$1" cfg="$2" tag="$3" stream="$4"
  export MRNIRP_STREAM="$stream"
  log "START $exp_id (stream=$stream)"
  bash scripts/repro/run_one.sh "$exp_id" "$cfg" > "logs/${tag}.log" 2>&1
  if grep -q "Traceback (most recent call last)" "$ROOT/experiments/$exp_id/run.log" 2>/dev/null; then
    log "END   $exp_id (FAILED - see experiments/$exp_id/run.log) | $(disk)"
  else
    log "END   $exp_id (ok) | $(disk)"
  fi
}

log "MR-NIRP pilot started (pid $$, host $(hostname)); MAX_FRAMES=$MRNIRP_MAX_FRAMES; $(disk)"

# ---- NIR stream ----
run E21_MRNIRP_NIR_unsup         "$ROOT/configs/repro/MRNIRP_NIR_UNSUPERVISED.yaml"   E21_nir_unsup          NIR
run E22_MRNIRP_NIR_physnet       "$ROOT/configs/repro/MRNIRP_NIR_PHYSNET.yaml"        E22_nir_physnet        NIR
run E23_MRNIRP_NIR_tscan         "$ROOT/configs/repro/MRNIRP_NIR_TSCAN.yaml"          E23_nir_tscan          NIR
run E24_MRNIRP_NIR_deepphys      "$ROOT/configs/repro/MRNIRP_NIR_DEEPPHYS.yaml"       E24_nir_deepphys       NIR
run E25_MRNIRP_NIR_efficientphys "$ROOT/configs/repro/MRNIRP_NIR_EFFICIENTPHYS.yaml"  E25_nir_efficientphys  NIR
run E26_MRNIRP_NIR_physformer    "$ROOT/configs/repro/MRNIRP_NIR_PHYSFORMER.yaml"     E26_nir_physformer     NIR

# ---- RGB stream ----
run E31_MRNIRP_RGB_unsup         "$ROOT/configs/repro/MRNIRP_RGB_UNSUPERVISED.yaml"   E31_rgb_unsup          RGB
run E32_MRNIRP_RGB_physnet       "$ROOT/configs/repro/MRNIRP_RGB_PHYSNET.yaml"        E32_rgb_physnet        RGB
run E33_MRNIRP_RGB_tscan         "$ROOT/configs/repro/MRNIRP_RGB_TSCAN.yaml"          E33_rgb_tscan          RGB
run E34_MRNIRP_RGB_deepphys      "$ROOT/configs/repro/MRNIRP_RGB_DEEPPHYS.yaml"       E34_rgb_deepphys       RGB
run E35_MRNIRP_RGB_efficientphys "$ROOT/configs/repro/MRNIRP_RGB_EFFICIENTPHYS.yaml"  E35_rgb_efficientphys  RGB
run E36_MRNIRP_RGB_physformer    "$ROOT/configs/repro/MRNIRP_RGB_PHYSFORMER.yaml"     E36_rgb_physformer     RGB

log "Building summary..."
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate rppg
python scripts/mrnirp/build_mrnirp_summary.py 2>&1 | tee -a "$STATUS"
log "ALL MR-NIRP PILOT DONE | $(disk)"
touch "$ROOT/logs/mrnirp.DONE"
