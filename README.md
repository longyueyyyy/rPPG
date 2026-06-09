# 车载远程生理监测 rPPG 项目

本文件是项目的操作入口。详细研究计划见 [`readme_guide.md`](./readme_guide.md)；文献与数据集调研见
[`docs/research/in_vehicle_rppg_survey.md`](./docs/research/in_vehicle_rppg_survey.md)。

目标：面向真实驾驶环境（运动、动态光照、夜间/近红外、道路振动），实现稳健的摄像头 rPPG，
输出心率/脉搏波（HR/BVP）、信号质量与拒绝决策。底座为
[rPPG-Toolbox](https://github.com/ubicomplab/rPPG-Toolbox)（固定在 `external/`，commit `b7500b8`）。

---

## 1. 运行环境（conda 环境 `rppg`）

由 [`scripts/setup/setup_env.sh`](scripts/setup/setup_env.sh) 一键构建。相对工具箱自带 `setup.sh`
有两处针对本机的必要改动：

- 使用 CUDA 11.8，而非 12.1。本机显卡驱动为 `470.256.02`（最高支持 CUDA 11.4）。工具箱的
  `setup.sh` 安装 `torch+cu121`，需要驱动不低于 525，在本机会失败。我们改装
  `torch==2.1.2+cu118`：CUDA 11.8 运行时依靠 CUDA 小版本兼容性可运行在 11.4 驱动上
  （已验证 `torch.cuda.is_available()` 为 True，4 张 RTX 3090 全部可用）。
- 跳过 `mamba-ssm` / `causal-conv1d`。二者需要 nvcc 工具链（本机仅装了驱动），且仅 PhysMamba
  使用。`neural_methods/model/PhysMamba.py` 中的 `from mamba_ssm import Mamba` 已用 try/except
  保护，因此除 PhysMamba 外全部模型可正常导入。

```bash
conda activate rppg          # Python 3.8.20, torch 2.1.2+cu118
```

## 2. 当前已跑通（首次复现）

详见 [`reports/baseline_benchmark/report.md`](reports/baseline_benchmark/report.md)。在 UBFC-rPPG
的 4 名受试者子集上，已在本机端到端验证：

- 7 个传统无监督基线（POS、CHROM、ICA、GREEN、LGI、PBV、OMIT）。POS/LGI/OMIT 的 MAE 约 0.22 bpm。
- 5 个预训练神经网络跨库推理（PURE 训练，UBFC 测试）：PhysNet、TS-CAN、DeepPhys、PhysFormer
  的 MAE 约 0.88 bpm；EfficientPhys 结果异常（已标注待查）。

注意：4 人子集只用于验证流程正确性与方法相对排序，不能代表论文中 42 人全集的平均指标。
要得到可对标论文的平均值，需扩充到完整数据集。详见报告中的说明。

## 3. 仓库结构

```
configs/repro/         复现用配置（子集路径，指标用 MACC 替代 BA）
data/UBFC-rPPG/UBFC/    原始子集（subject1,3,4,5）；data/processed/ 为预处理缓存
docs/research/         车载调研报告 + 经核实的数据集获取状态
experiments/E0*/        每次实验的 config + environment + run.log + metrics.json
external/rPPG-Toolbox/  固定的上游工具箱（仅一处可追溯改动：PhysMamba 的 import 保护）
reports/baseline_benchmark/report.md
scripts/setup|download|repro/   环境搭建、数据下载、运行与解析脚本
```

## 4. 复现与扩展命令

```bash
# 无监督在 CPU 上运行；神经网络在 GPU 上运行
bash scripts/repro/run_one.sh E01_unsup_UBFCsubset  configs/repro/UBFC_subset_UNSUPERVISED.yaml
bash scripts/repro/run_one.sh E02_PURE2UBFC_physnet configs/repro/PURE_UBFC_subset_PHYSNET.yaml
python scripts/repro/parse_metrics.py logs/E01_unsup.log --kind unsupervised --label unsup

# 下载更多 UBFC 受试者（每人约 1.3 至 1.9 GB，注意磁盘）
bash scripts/download/get_ubfc_subset.sh "8 9 10 11"
```

## 5. 数据集获取状态（截至 2026 年中，已核实，详见调研报告）

| 数据集 | 可否获取 | 方式 |
|---|---|---|
| UBFC-rPPG | 开放 | HuggingFace 镜像 `thachha901/UBFC`（本项目所用）或官方 Google Drive |
| CHILL | 受限（EULA+邮件） | 需先签署 EULA，再在 Zenodo `10.5281/zenodo.14637544` 申请访问（已发布 23 名受试者，36×36 帧仅供评估、不可训练）；低光/高心率 |
| PhysDrive | 部分 | HF `canliu0312/PhysDrive` 仅含 1 名 RGB 受试者样本 + mmWave；格式为 `RGB.mp4` + 会话 `AS/AT/...`，需为加载器做适配 |
| MMPD / PURE / iBVP / UBFC-Phys | 受限 | 需签署协议 / 邮件申请 / IEEE 账号 |
| MMDrive | 未发布 | 仓库自 2025 年 4 月起标注"即将发布"，暂无数据 |

## 6. 路线图（下一步）

1. 扩充 UBFC 受试者，得到可对标论文 Table 2 的稳定平均值；排查 EfficientPhys 异常。
2. 并行提交 CHILL 的 EULA 申请（受限，需邮件审批），作为低光 / 高心率的评估目标（仅评估，不训练）。
3. 为 PhysDrive 写加载器适配（`RGB.mp4` + 会话 `AS/AT/BS/...`），得到首批车载数字，
   包括"实验室到车载"的跨域性能掉落（项目的核心动机）。
4. 基于已保存的 BVP 波形输出，启动 Stage-2 质量门控（SQI + 拒绝机制）。
