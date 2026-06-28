#!/bin/bash
# Install the project's MR-NIRP loader into external/rPPG-Toolbox (gitignored, pinned b7500b8).
# Idempotent: safe to re-run. Adds MRNIRPLoader.py + registers "MR-NIRP" dispatch in main.py
# and the data_loader package. Run after a fresh toolbox checkout.
set -euo pipefail
ROOT=/home/lsg/rPPG
TB="$ROOT/external/rPPG-Toolbox"

cp "$ROOT/scripts/mrnirp/MRNIRPLoader.py" "$TB/dataset/data_loader/MRNIRPLoader.py"
echo "copied MRNIRPLoader.py"

python - "$TB" <<'PY'
import sys, io, os
TB = sys.argv[1]

def patch(path, anchor, insert, marker):
    with io.open(path, encoding="utf-8") as f:
        s = f.read()
    if marker in s:
        print(f"[skip] {os.path.basename(path)} already patched ({marker!r})")
        return
    if anchor not in s:
        raise SystemExit(f"[ERR] anchor not found in {path}: {anchor!r}")
    s = s.replace(anchor, insert + anchor, 1)
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(s)
    print(f"[ok] patched {os.path.basename(path)}")

# 1) package import
patch(os.path.join(TB, "dataset/data_loader/__init__.py"),
      "import dataset.data_loader.SUMSLoader",
      "import dataset.data_loader.MRNIRPLoader\n",
      "MRNIRPLoader")

main = os.path.join(TB, "main.py")
# 2) only_test dispatch (anchor on the TEST-specific SUMS branch)
patch(main,
      '        elif config.TEST.DATA.DATASET == "SUMS":\n'
      '            test_loader = data_loader.SUMSLoader.SUMSLoader\n',
      '        elif config.TEST.DATA.DATASET == "MR-NIRP":\n'
      '            test_loader = data_loader.MRNIRPLoader.MRNIRPLoader\n',
      'TEST.DATA.DATASET == "MR-NIRP"')
# 3) unsupervised_method dispatch (anchor on the UNSUPERVISED iBVP branch)
patch(main,
      '        elif config.UNSUPERVISED.DATA.DATASET == "iBVP":\n'
      '            unsupervised_loader = data_loader.iBVPLoader.iBVPLoader\n',
      '        elif config.UNSUPERVISED.DATA.DATASET == "MR-NIRP":\n'
      '            unsupervised_loader = data_loader.MRNIRPLoader.MRNIRPLoader\n',
      'UNSUPERVISED.DATA.DATASET == "MR-NIRP"')
PY
echo "MR-NIRP loader installed."
