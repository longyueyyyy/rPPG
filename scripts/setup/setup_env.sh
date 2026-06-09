#!/bin/bash
# =============================================================================
# Conda environment setup for rPPG-Toolbox on this machine.
#
# Why this differs from external/rPPG-Toolbox/setup.sh:
#   * The GPU driver here is 470.256.02 (supports CUDA <= 11.4). The toolbox's
#     setup.sh installs torch+cu121 (CUDA 12.1), which REQUIRES driver >= 525
#     and would fail with "CUDA driver version is insufficient". We instead
#     install the cu118 build: CUDA 11.8 runtime runs fine on a 11.4 driver via
#     CUDA minor-version compatibility (verified: torch 2.5.1+cu118 already sees
#     the RTX 3090s in the existing `ML` env).
#   * We SKIP mamba-ssm / causal-conv1d. They require an nvcc CUDA toolkit
#     (only the driver is installed here) and a source build. They are only
#     needed for PhysMamba; all other baselines/models work without them.
#
# Usage:  bash scripts/setup/setup_env.sh
# =============================================================================
set -euo pipefail

ENV_NAME="rppg"
PY_VER="3.8"
TOOLBOX_DIR="/home/lsg/rPPG/external/rPPG-Toolbox"
TORCH_INDEX="https://download.pytorch.org/whl/cu118"

echo "==== [1/5] conda base ===="
source "$(conda info --base)/etc/profile.d/conda.sh"

echo "==== [2/5] (re)create env '$ENV_NAME' (python $PY_VER) ===="
conda env remove -n "$ENV_NAME" -y 2>/dev/null || true
conda create -n "$ENV_NAME" python="$PY_VER" -y
conda activate "$ENV_NAME"
python --version

echo "==== [3/5] install torch 2.1.2 + cu118 (driver-470 compatible) ===="
pip install --no-cache-dir \
    torch==2.1.2+cu118 torchvision==0.16.2+cu118 torchaudio==2.1.2+cu118 \
    --index-url "$TORCH_INDEX"

echo "==== [4/5] install toolbox requirements (minus mamba-ssm / causal-conv1d) ===="
# pip mirror (Tsinghua TUNA) is inherited from ~/.config/pip; only torch uses the pytorch index above.
grep -vE '^(mamba-ssm|causal-conv1d)' "$TOOLBOX_DIR/requirements.txt" \
    > /home/lsg/rPPG/scripts/setup/requirements-no-mamba.txt
pip install --no-cache-dir -r /home/lsg/rPPG/scripts/setup/requirements-no-mamba.txt

echo "==== [5/5] verify torch + CUDA ===="
python - <<'PY'
import torch
print("torch        :", torch.__version__)
print("cuda build   :", torch.version.cuda)
print("is_available :", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device count :", torch.cuda.device_count())
    print("device name  :", torch.cuda.get_device_name(0))
    # real forward pass on GPU to confirm kernels run on this driver
    x = torch.randn(256, 256, device="cuda")
    y = (x @ x).sum().item()
    print("gpu matmul ok:", y is not None)
PY

echo ""
echo "==== DONE. Activate with: conda activate $ENV_NAME ===="
