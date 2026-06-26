# 车载驾驶员 rPPG 监测

用普通摄像头从驾驶员面部视频估计心率和脉搏波（HR / BVP），目标是在真实行车环境——头部运动、动态光照、夜间、道路颠簸——下仍然稳健，并在信号不可靠时主动给出质量评分与拒绝结果。底座是 [rPPG-Toolbox](https://github.com/ubicomplab/rPPG-Toolbox)（固定在 commit `b7500b8`）。

目前处于**基线复现阶段**：先把整条流水线在本机跑通、验证方法间排序与文献一致，再往车载场景推进。

## 范围与边界

这个项目做的是非接触脉搏测量与异常筛查，不是临床诊断。几条原则贯穿始终：

- rPPG/BVP 是光学脉搏信号，**不等于 ECG**。视频模型默认输出 BVP / HR / 信号质量，不声称重建有诊断效力的 ECG。
- 不做心梗（MI / ACS）诊断。急性冠脉事件的判断依赖症状、ECG 和肌钙蛋白等证据，摄像头 rPPG 不替代这些。后期若拿到同步 ECG，方向是"ECG 监督下的表征学习与风险筛查"，而非视频版 ECG。
- 未实际跑出来的结果一律标 TODO，不填估计值。

更完整的研究动机、可行性分级和分阶段路线见 [`README_GUIDE_lsg.md`](README_GUIDE_lsg.md)（给人看的研究指导）。车载场景的文献综述与数据集获取细节见 [`docs/research/in_vehicle_rppg_survey.md`](docs/research/in_vehicle_rppg_survey.md)。

## 目前做了什么

2026-06-02 在本机完成首次端到端复现，数据是 UBFC-rPPG 的 4 名受试者子集 `{1, 3, 4, 5}`（取自 HuggingFace 镜像 `thachha901/UBFC`，640×480，约 30 fps，真值为接触式 PPG 的 BVP）。人脸用 Haar Cascade 裁剪、缩放到 72×72（PhysFormer 用 128×128），心率用 FFT 估计。完整报告见 [`reports/baseline_benchmark/report.md`](reports/baseline_benchmark/report.md)，逐实验记录见 [`experiments/`](experiments/)。

**传统无监督方法**（无需训练，UBFC 子集）：

| 方法 | MAE (bpm) | RMSE | Pearson r | MACC |
|---|---:|---:|---:|---:|
| POS | 0.22 | 0.44 | 0.999 | 0.77 |
| LGI | 0.22 | 0.44 | 0.999 | 0.70 |
| OMIT | 0.22 | 0.44 | 0.999 | 0.70 |
| CHROM | 1.32 | 2.64 | 0.974 | 0.76 |
| PBV | 3.52 | 7.03 | 0.756 | 0.65 |
| ICA | 8.79 | 16.71 | 0.963 | 0.59 |
| GREEN | 9.89 | 16.91 | 0.943 | 0.59 |

**预训练神经网络跨库推理**（PURE 上训练的权重，UBFC 子集上测试，本机不训练）：

| 模型 | MAE (bpm) | RMSE | Pearson r | MACC |
|---|---:|---:|---:|---:|
| PhysNet | 0.88 | 1.76 | 0.996 | 0.81 |
| TS-CAN | 0.88 | 1.76 | 0.996 | 0.83 |
| DeepPhys | 0.88 | 1.76 | 0.996 | 0.82 |
| PhysFormer | 0.88 | 1.76 | 0.996 | 0.76 |
| EfficientPhys | 16.04 | 30.37 | -0.14 | 0.69 |

要点：

- 投影/色度类方法（POS、LGI、OMIT、CHROM）明显领先 GREEN、ICA，与文献一致。
- 四个神经网络在这几段干净视频上落到同一个 FFT 心率频点，所以 MAE 完全相同（0.88）；只有 SNR / MACC 能区分它们。
- EfficientPhys 结果异常（MAE 16，负相关），已标为待查，不作结论——n=4 时负相关基本等于噪声，需在更多受试者上重测，并检查推理阶段的归一化。
- **这 4 人子集只用来验证流程正确和方法排序，绝对指标不能和论文里 42 人全集的平均值比。**

## 仓库结构

这个 Git 仓库只跟踪项目骨架。数据集、`external/rPPG-Toolbox`、日志、模型权重都不入库（见 `.gitignore`），在各机器本地按约定存放，不随仓库分发。

```
configs/repro/        复现用 YAML 配置（子集路径）
docs/research/        车载文献综述 + 已核实的数据集获取状态 + 参考文献
experiments/E0*/       每个实验的 config + environment + metrics.json；汇总见 all_metrics.json
reports/baseline_benchmark/report.md    首次复现报告
scripts/setup/         环境搭建（setup_env.sh、依赖清单）
scripts/download/      数据下载（get_ubfc_subset.sh）
scripts/repro/         运行与解析（run_one.sh、run_extra_neural.sh、parse_metrics.py）
external/rPPG-Toolbox/  上游工具箱（不入库，固定 commit b7500b8）
data/                  数据集缓存目录（不入库；也可指向仓库外的数据盘）
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
# 无监督方法在 CPU 上跑，神经网络在 GPU 上跑
bash scripts/repro/run_one.sh E01_unsup_UBFCsubset  configs/repro/UBFC_subset_UNSUPERVISED.yaml
bash scripts/repro/run_one.sh E02_PURE2UBFC_physnet configs/repro/PURE_UBFC_subset_PHYSNET.yaml

# 从日志解析指标
python scripts/repro/parse_metrics.py logs/E01_unsup.log --kind unsupervised --label unsup

# 下载更多 UBFC 受试者（每人约 1.3–1.9 GB，注意磁盘）
bash scripts/download/get_ubfc_subset.sh "8 9 10 11"
```

`run_one.sh` 会把配置、环境信息（python / torch / 工具箱 commit）和运行日志一并存进 `experiments/<exp_id>/`，便于追溯。

## 数据集获取状态

截至 2026 年中已逐一核实，完整说明（邮箱、协议、中国大陆可达性、磁盘体量）见 [`docs/research/in_vehicle_rppg_survey.md`](docs/research/in_vehicle_rppg_survey.md) 第 5 节和 [`docs/research/dataset_access_verifications.json`](docs/research/dataset_access_verifications.json)。

| 数据集 | 可否获取 | 方式 |
|---|---|---|
| UBFC-rPPG | 开放 | 官方公开 Google Drive，或 Kaggle / HuggingFace 镜像（本项目用后者） |
| PURE | 受限 | 邮件申请（TU Ilmenau） |
| MMPD | 受限 | 教职工签协议（用 Mini 48 GB 版本） |
| PhysDrive | 部分开放 | Kaggle 有预处理子集；完整原始数据需邮件签协议 |
| CHILL | 受限 | EULA + 邮件审批；仅 23 人、36×36，只能评估不能训练 |
| MR-NIRP (Driving) | 开放 | Google Drive（中国大陆需代理） |
| MMDrive | 未发布 | 仓库自 2025-04 标"即将发布"，至今无数据 |

## 下一步

近期计划，按优先级：

1. **扩充 UBFC 受试者**到全集（或更大的分层子集），得到可与论文对标的平均值；同时排查 EfficientPhys 异常。
2. **并行提交受限数据集申请**——PURE、MMPD（教职工协议）、PhysDrive 原始数据、CHILL EULA。真正的关键路径是审批延迟而非下载，越早发越好。
3. **加跨数据集压力测试**：UBFC / PURE → MMPD，亲眼看到深度模型跨库掉点（这才是车载落地真正在意的泛化）。
4. **写 PhysDrive 加载器适配**（HF 格式是 `RGB.mp4` + 会话 `AS/AT/...`，工具箱加载器期望 `Align/*.png` + `A1/A2/...`），拿到第一批车载数字和"实验室→车载"的掉点——这是项目的核心动机。
5. **启动质量门控（Stage 2）**：基于已保存的 BVP 波形输出做 SQI + 拒绝机制，在工具箱现有的 `reject<0.5` 门控基础上扩展为带校准的质量评分与选择性预测（综述第 4 节指出的创新空白）。
