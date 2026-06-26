# 车载驾驶员 rPPG 监测

用普通摄像头从驾驶员面部视频估计心率和脉搏波（HR / BVP），目标是在真实行车环境——头部运动、动态光照、夜间、道路颠簸——下仍然稳健，并在信号不可靠时主动给出质量评分与拒绝结果。底座是 [rPPG-Toolbox](https://github.com/ubicomplab/rPPG-Toolbox)（固定在 commit `b7500b8`）。

目前处于**基线复现阶段**：先把整条流水线在本机跑通、验证方法间排序与文献一致，再往车载场景推进。

## 范围与边界

这个项目做的是非接触脉搏测量与异常筛查，不是临床诊断。几条原则贯穿始终：

- rPPG/BVP 是光学脉搏信号，**不等于 ECG**。视频模型默认输出 BVP / HR / 信号质量，不声称重建有诊断效力的 ECG。
- 不做心梗（MI / ACS）诊断。急性冠脉事件的判断依赖症状、ECG 和肌钙蛋白等证据，摄像头 rPPG 不替代这些。后期若拿到同步 ECG，方向是"ECG 监督下的表征学习与风险筛查"，而非视频版 ECG。
- 未实际跑出来的结果一律标 TODO，不填估计值。

车载场景的文献综述与数据集获取细节见 [`docs/research/in_vehicle_rppg_survey.md`](docs/research/in_vehicle_rppg_survey.md)。

## 目前做了什么

2026-06-26 在本机跑完 **UBFC-rPPG 全集**（42 名受试者，取自 HuggingFace 镜像 `thachha901/UBFC`，640×480，约 30 fps，真值为接触式 PPG 的 BVP）。人脸用 Haar Cascade 裁剪、缩放到 72×72（PhysFormer 用 128×128），心率用 FFT 估计。汇总见 [`reports/baseline_benchmark/full_ubfc_summary.md`](reports/baseline_benchmark/full_ubfc_summary.md)，逐实验记录见 [`experiments/`](experiments/)。

**传统无监督方法**（无需训练，UBFC 全集 42 人）：

| 方法 | MAE (bpm) | RMSE | Pearson r | MACC |
|---|---:|---:|---:|---:|
| CHROM | 3.31 | 7.28 | 0.917 | 0.69 |
| POS | 3.52 | 8.85 | 0.899 | 0.71 |
| ICA | 15.62 | 27.02 | 0.468 | 0.53 |
| PBV | 16.76 | 30.42 | 0.417 | 0.49 |
| LGI | 18.94 | 33.21 | 0.264 | 0.51 |
| OMIT | 18.94 | 33.21 | 0.264 | 0.51 |
| GREEN | 22.60 | 36.10 | 0.302 | 0.44 |

**预训练神经网络跨库推理**（PURE 上训练的权重，UBFC 全集上测试，本机不训练）：

| 模型 | MAE (bpm) | RMSE | Pearson r | MACC |
|---|---:|---:|---:|---:|
| DeepPhys | 1.26 | 2.97 | 0.989 | 0.83 |
| PhysFormer | 1.38 | 3.74 | 0.977 | 0.79 |
| TS-CAN | 1.42 | 2.98 | 0.988 | 0.84 |
| PhysNet | 2.68 | 7.54 | 0.917 | 0.73 |
| EfficientPhys | 2.68 | 9.77 | 0.867 | 0.79 |

要点：

- 神经网络明显优于传统方法：最好的 DeepPhys（MAE 1.26）远好于最好的无监督 CHROM（3.31）。绝对指标回到文献量级，可与论文里 42 人全集的均值对标。
- 无监督里投影/色度类（CHROM、POS，MAE 约 3.3–3.5）领先一档；ICA / PBV / LGI / OMIT / GREEN 在难样本上大幅退化（15–23 bpm）。排序与文献一致。
- **EfficientPhys 的"异常"在全集上消失了**：子集（n=4）上它是 MAE 16.04、Pearson −0.14（曾标为待查），全集上变成 MAE 2.68、Pearson 0.867，完全正常。证实那是小样本下"负相关≈噪声"的假象，不是模型或推理归一化的问题。
- 全集让模型之间有了区分度：子集上四个网络都落到同一 FFT 频点、MAE 完全相同（0.88），全集上正常分开（DeepPhys / PhysFormer / TS-CAN ≈1.3，PhysNet / EfficientPhys ≈2.7）。

## 仓库结构

这个 Git 仓库只跟踪项目骨架。数据集、`external/rPPG-Toolbox`、日志、模型权重都不入库（见 `.gitignore`），在各机器本地按约定存放，不随仓库分发。

```
configs/repro/        复现用 YAML 配置（全集路径 UBFC_full_*.yaml）
docs/research/        车载文献综述 + 已核实的数据集获取状态 + 参考文献
experiments/E1*/       每个实验的 config + environment + metrics.json；汇总见 all_metrics_full.json
reports/baseline_benchmark/full_ubfc_summary.md   全集（42 人）基准汇总表
scripts/setup/         环境搭建（setup_env.sh、依赖清单）
scripts/download/      数据下载（get_ubfc_subset.sh）
scripts/repro/         运行与解析（run_full_ubfc.sh、run_one.sh、build_full_summary.py、parse_metrics.py）
external/rPPG-Toolbox/  上游工具箱（不入库，固定 commit b7500b8）
/media/amdin/Drive1/rppg_data/ 数据集缓存目录（不入库；也可指向仓库外的数据盘）
```

## 运行环境

conda 环境 `rppg`（Python 3.8，torch 2.1.2+cu118），由 [`scripts/setup/setup_env.sh`](scripts/setup/setup_env.sh)（Linux）或 [`scripts/setup/setup_env.ps1`](scripts/setup/setup_env.ps1)（Windows）构建。相对工具箱自带 `setup.sh` 有两处改动：

- **用 CUDA 11.8 而非工具箱默认的 12.1**。在驱动较旧的机器上 `torch+cu121` 需要驱动 ≥525 会失败；`torch==2.1.2+cu118` 通过 CUDA 小版本兼容性适配范围更广，新旧驱动都能用（已在 RTX 3090 与 RTX 4060 上验证 `torch.cuda.is_available()` 为 True）。
- **跳过 `mamba-ssm` / `causal-conv1d`**。两者需要 nvcc 工具链，且只有 PhysMamba 用到；`PhysMamba.py` 的 `from mamba_ssm import Mamba` 已用 try/except 保护，因此除 PhysMamba 外所有模型正常导入。

```bash
conda activate rppg
```

## 复现

```bash
# 一条命令后台跑完整套全集基准（无监督在 CPU、神经网络在 GPU，串行；可退出登录继续跑）
bash scripts/repro/run_full_ubfc.sh
# 产出 experiments/E11–E16、experiments/all_metrics_full.json 和上面的汇总表

# 或单跑某一个实验（注意：run_one.sh 会 cd 进工具箱，配置路径必须用绝对路径）
bash scripts/repro/run_one.sh E11_unsup_UBFCfull /home/lsg/rPPG/configs/repro/UBFC_full_UNSUPERVISED.yaml

# 从日志解析指标
python scripts/repro/parse_metrics.py logs/E11_unsup.log --kind unsupervised --label unsup
```

预处理缓存约 74 GB，落在数据盘 `/media/amdin/Drive1/rppg_data/processed/UBFC_full_*`（`/home` 空间不足）；保存的 BVP 波形和日志体量小，留在 `/home/lsg/rPPG`。`run_one.sh` 会把配置、环境信息（python / torch / 工具箱 commit）和运行日志一并存进 `experiments/<exp_id>/`，便于追溯。

## 数据集获取状态

截至 2026 年中已逐一核实，完整说明见 [`docs/research/in_vehicle_rppg_survey.md`](docs/research/in_vehicle_rppg_survey.md) 第 5 节和 [`docs/research/dataset_access_verifications.json`](docs/research/dataset_access_verifications.json)。

| 数据集 | 可否获取 | 方式 |
|---|---|---|
| UBFC-rPPG | 开放 | 官方公开 Google Drive，或 Kaggle / HuggingFace 镜像（本项目用后者） |
| PURE | 受限 | 邮件申请（TU Ilmenau） |
| MMPD | 受限 | 教职工签协议（用 Mini 48 GB 版本） |
| PhysDrive | 部分开放 | Kaggle 有预处理子集；完整原始数据需邮件签协议 |
| CHILL | 受限 | EULA + 邮件审批；仅 23 人、36×36，只能评估不能训练 |
| MR-NIRP (Driving) | 开放 | Google Drive |

## 下一步

UBFC 全集基准已跑通（见上），EfficientPhys 的子集异常也已确认是小样本假象。接下来按优先级：

1. **并行提交受限数据集申请**——PURE、MMPD（教职工协议）、PhysDrive 原始数据、CHILL EULA。真正的关键路径是审批延迟而非下载，越早发越好。
2. **加跨数据集压力测试**：UBFC / PURE → MMPD，亲眼看到深度模型跨库掉点（这才是车载落地真正在意的泛化）。
3. **写 PhysDrive 加载器适配**（HF 格式是 `RGB.mp4` + 会话 `AS/AT/...`，工具箱加载器期望 `Align/*.png` + `A1/A2/...`），拿到第一批车载数字和"实验室→车载"的掉点——这是项目的核心动机。
4. **启动质量门控（Stage 2）**：基于已保存的 BVP 波形输出做 SQI + 拒绝机制，在工具箱现有的 `reject<0.5` 门控基础上扩展为带校准的质量评分与选择性预测（综述第 4 节指出的创新空白）。
