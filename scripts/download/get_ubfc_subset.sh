#!/bin/bash
# Download a SUBSET of UBFC-rPPG subjects from the HuggingFace mirror thachha901/UBFC,
# using plain curl on the resolve/ URLs (follows the signed Xet-CDN redirect; supports
# resume with -C -). This is more robust from a China network than the hf python client.
#
# Usage: bash get_ubfc_subset.sh "1 3 4 5"
set -uo pipefail

SUBJECTS="${1:-1 3 4 5}"
DEST="/home/lsg/rPPG/data/UBFC-rPPG/UBFC"     # loader DATA_PATH = this dir (contains subject*)
BASE="https://huggingface.co/datasets/thachha901/UBFC/resolve/main/UBFC"

mkdir -p "$DEST"
echo "Downloading UBFC subjects: $SUBJECTS  ->  $DEST"

fail=0
for s in $SUBJECTS; do
    d="$DEST/subject${s}"
    mkdir -p "$d"
    echo ""
    echo "==== subject${s} ===="
    # ground truth (small, regular git file)
    curl -fL -C - --retry 5 --retry-delay 3 -o "$d/ground_truth.txt" \
        "$BASE/subject${s}/ground_truth.txt" || { echo "FAIL gt subject${s}"; fail=1; }
    # video (LFS/Xet, ~1.3-1.9 GB) -- show progress
    curl -fL -C - --retry 5 --retry-delay 3 --progress-bar -o "$d/vid.avi" \
        "$BASE/subject${s}/vid.avi" || { echo "FAIL vid subject${s}"; fail=1; }
    sz=$(du -h "$d/vid.avi" 2>/dev/null | cut -f1)
    echo "subject${s}: vid.avi=${sz}"
done

echo ""
echo "=== downloaded tree ==="
ls -la "$DEST"/subject* 2>/dev/null | grep -E "subject|vid|ground" | head -40
echo "=== disk free ==="; df -h /home/lsg | tail -1
echo "=== DONE (fail=$fail) ==="
exit $fail
