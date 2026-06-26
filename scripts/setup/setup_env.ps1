# Windows 上为 rPPG-Toolbox 创建 conda 环境，对应 setup_env.sh。
# 创建 conda 环境 rppg（Python 3.8）+ torch 2.1.2+cu118 + 工具箱依赖（去掉 mamba-ssm / causal-conv1d）。
#
# 为什么和工具箱自带 setup.sh 不同：
#   * 用 cu118 而非 cu121：cu121 需要较新的 GPU 驱动；cu118 通过 CUDA 小版本兼容性适配范围更广。
#   * 跳过 mamba-ssm / causal-conv1d：需要 nvcc 工具链且仅 PhysMamba 用到，已用 try/except 保护。
#
# 用法：  powershell -ExecutionPolicy Bypass -File scripts\setup\setup_env.ps1

$ErrorActionPreference = 'Stop'
$envName = 'rppg'
$req = Join-Path $PSScriptRoot 'requirements-no-mamba.txt'

Write-Host "==== [1/4] create env '$envName' (python 3.8) ===="
conda create -n $envName python=3.8 -y
$py = Join-Path ((conda info --base).Trim()) "envs\$envName\python.exe"
Write-Host "env python: $py"

Write-Host "==== [2/4] install torch 2.1.2+cu118 (from pytorch.org) ===="
& $py -m pip install --no-cache-dir torch==2.1.2+cu118 torchvision==0.16.2+cu118 torchaudio==2.1.2+cu118 --index-url https://download.pytorch.org/whl/cu118

Write-Host "==== [3/4] install toolbox requirements (Tsinghua mirror) ===="
& $py -m pip install --no-cache-dir -r $req -i https://pypi.tuna.tsinghua.edu.cn/simple

Write-Host "==== [4/4] verify torch + CUDA ===="
& $py -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'avail', torch.cuda.is_available()); print('dev', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')"

Write-Host ""
Write-Host "==== DONE. Activate with: conda activate $envName ===="
