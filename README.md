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

## 车载初探：MR-NIRP (Driving) 试点

2026-06-28 在 [MR-NIRP Car](docs/research/in_vehicle_rppg_survey.md) 上跑通第一批车载数据——这是项目从实验室转向真实行车的第一步。工具箱没有 MR-NIRP 加载器，自己写了一个（`scripts/mrnirp/`）。用 PURE 预训练权重跨库推理，**NIR 与 RGB 两个成像通道都跑**，方法同 UBFC（无监督 + 5 个神经网络）。汇总见 [`reports/baseline_benchmark/mrnirp_pilot_summary.md`](reports/baseline_benchmark/mrnirp_pilot_summary.md)。

数据是**部分下载**（完整 190 段视频里大部分没下；详见 [审计清单](reports/baseline_benchmark/mrnirp_unusable_list.txt)）。删掉损坏/残片、并从官方 Drive 补齐缺失真值后，**可用视频+真值 NIR n=23、RGB n=29**（覆盖 Subject 1/3/10/11/14–19），每会话截取前 ~150 s。

**RGB 通道**（去 Bayer，n=29）：

| 方法 | MAE (bpm) | Pearson r | MACC | |
|---|---:|---:|---:|---|
| POS | 13.96 | 0.55 | 0.18 | 无监督 |
| CHROM | 14.16 | 0.44 | 0.17 | 无监督 |
| PhysFormer | 17.77 | 0.31 | 0.16 | 神经网络 |
| PBV | 18.87 | 0.35 | 0.16 | 无监督 |
| DeepPhys | 20.52 | 0.16 | 0.16 | 神经网络 |
| PhysNet | 23.66 | −0.01 | 0.15 | 神经网络 |
| TS-CAN | 24.70 | −0.08 | 0.14 | 神经网络 |
| EfficientPhys | 33.38 | −0.17 | 0.14 | 神经网络 |

（其余无监督：ICA 22.77 / LGI 22.59 / OMIT 22.62 / GREEN 24.28，均明显差于 POS/CHROM。）

**NIR 通道**（n=23）：所有方法基本失效——PhysNet 22.13（最好）、GREEN 24.21，DeepPhys / EfficientPhys / PhysFormer / TS-CAN 26–28，MACC ~0.14–0.15、Pearson ≈ 0。

要点：

- **实验室→车载断崖式掉点**：同一批方法在 UBFC 全集上 MAE ~1–3.5、MACC ~0.8，到了车载 RGB 变成 **MAE ~14–33、MACC ~0.15**。这正是项目要量化的泛化鸿沟。
- **RGB ≫ NIR**：单通道 NIR 上一切都失效（色度方法在复制成 3 通道后退化，只有 GREEN 有意义，但车内弱信号 + 暗帧让它也只有 MAE ~24）；RGB 虽被近红外照明污染，仍保留可用脉搏信号（最好 POS 13.96）。
- **车载里传统反超深度**：POS / CHROM（13.96 / 14.16）好过所有 PURE 预训练神经网络（最好 PhysFormer 17.77）——深度模型过拟合实验室域，跨到车载更脆。
- **EfficientPhys 又是最差**（33.38，负相关），和 UBFC 上"对域偏移最敏感"一致。
- **结论稳健、非单受试者假象**：把样本从最初偏向 Subject1 的 14/23 扩到更均衡的 23/29 后，上述排序与量级完全不变。
- 绝对值都很差、MACC 极低，说明**现成方法直接搬到车载不可用**——质量门控（拒绝不可靠片段）和域适配是后续重点。

## 仓库结构

这个 Git 仓库只跟踪项目骨架。数据集、`external/rPPG-Toolbox`、日志、模型权重都不入库（见 `.gitignore`），在各机器本地按约定存放，不随仓库分发。

```
configs/repro/        复现用 YAML 配置（UBFC_full_*.yaml、MRNIRP_{NIR,RGB}_*.yaml）
docs/research/        车载文献综述 + 已核实的数据集获取状态 + 参考文献
experiments/E1*/       UBFC 全集实验；E2*/E3* 为 MR-NIRP 试点。每个含 config + environment + metrics.json
reports/baseline_benchmark/    full_ubfc_summary.md（UBFC 全集）、mrnirp_pilot_summary.md（MR-NIRP 试点）
scripts/setup/         环境搭建（setup_env.sh、依赖清单）
scripts/download/      数据下载（get_ubfc_subset.sh）
scripts/repro/         运行与解析（run_full_ubfc.sh、run_one.sh、build_full_summary.py、parse_metrics.py）
scripts/mrnirp/        MR-NIRP 加载器与流程（MRNIRPLoader.py、install_into_toolbox.sh、generate_configs.py、run_mrnirp_pilot.sh）
external/rPPG-Toolbox/  上游工具箱（不入库，固定 commit b7500b8；MR-NIRP 加载器由 install 脚本注入）
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

UBFC 全集基准已跑通、MR-NIRP 车载试点也拿到第一批掉点数字（见上）。接下来按优先级：

1. **MR-NIRP 按条件细分 / 继续补数据**：缺失真值已补齐（现 video+GT 为 NIR 23 / RGB 29 个会话），下一步按条件分解指标（still / small / large motion、driving vs garage），看运动与场景对掉点的影响，而非现在的混合均值；想要群体级结论还需从官方 Drive 补下更多视频（完整 190 段大部分未下）。
2. **启动质量门控（Stage 2）**：车载绝对误差大、MACC 极低，最该做的是 SQI + 拒绝机制——基于已保存的 BVP 波形输出，在工具箱现有的 `reject<0.5` 门控上扩展为带校准的质量评分与选择性预测（综述第 4 节的创新空白）。
3. **并行提交受限数据集申请**——PURE、MMPD（教职工协议）、PhysDrive 原始数据、CHILL EULA。关键路径是审批延迟而非下载，越早发越好。
4. **写 PhysDrive 加载器适配**（HF 格式是 `RGB.mp4` + 会话 `AS/AT/...`，工具箱加载器期望 `Align/*.png` + `A1/A2/...`），拿到另一个车载数据集的对照。
