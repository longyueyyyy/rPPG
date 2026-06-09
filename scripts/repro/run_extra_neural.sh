#!/bin/bash
set -uo pipefail
cd /home/lsg/rPPG
run() { bash scripts/repro/run_one.sh "$1" "$2" > "logs/$3.log" 2>&1; echo "[done] $1 -> logs/$3.log"; }
run E04_PURE2UBFC_deepphys      /home/lsg/rPPG/configs/repro/PURE_UBFC_subset_DEEPPHYS.yaml      E04_deepphys
run E05_PURE2UBFC_efficientphys /home/lsg/rPPG/configs/repro/PURE_UBFC_subset_EFFICIENTPHYS.yaml E05_efficientphys
run E06_PURE2UBFC_physformer    /home/lsg/rPPG/configs/repro/PURE_UBFC_subset_PHYSFORMER.yaml    E06_physformer
echo "ALL EXTRA NEURAL DONE"
