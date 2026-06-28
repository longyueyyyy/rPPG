# 实验记录

每个实验一个目录（`E1*` 为 UBFC 全集，`E2*/E3*` 为 MR-NIRP 车载试点），里面固定三个文件：

- `config.yaml` —— 运行用的完整配置（含数据路径、预处理、评估方式）
- `environment.txt` —— 溯源信息：日期、Python / torch 版本、工具箱 commit
- `metrics.json` —— 该实验的指标

汇总指标在 [`all_metrics_full.json`](all_metrics_full.json)，可读的汇总表在 [`../reports/baseline_benchmark/full_ubfc_summary.md`](../reports/baseline_benchmark/full_ubfc_summary.md)。运行日志（`run.log`）体量大但仍留在各实验目录；约 74 GB 的预处理缓存不入库，放在数据盘 `/media/amdin/Drive1/rppg_data/processed/UBFC_full_*`。

UBFC 全集实验（E11–E16）跑于 2026-06-26，conda 环境 `rppg`（Python 3.8.20，torch 2.1.2+cu118），4×RTX 3090，驱动 470 / CUDA 11.4，工具箱固定 commit `b7500b8`，数据是 **UBFC-rPPG 全集（42 名受试者）**，整套约 40 分钟跑完。MR-NIRP 试点（E21–E36）同环境，跑于 2026-06-28（详见下方独立小节）。

> 早期的 4 人子集冒烟测试（E01–E06，`{1, 3, 4, 5}`）只用于验证流水线，已随全集结果出炉删除。

## 实验清单

| ID | 类型 | 训练 → 测试 | 方法 | MAE (bpm) | 状态 |
|---|---|---|---|---:|---|
| E11 | 无监督 | 无训练 → UBFC 全集 | CHROM / POS / ICA / PBV / LGI / OMIT / GREEN | 3.31–22.60 | 完成 |
| E12 | 神经网络跨库 | PURE → UBFC 全集 | PhysNet | 2.68 | 完成 |
| E13 | 神经网络跨库 | PURE → UBFC 全集 | TS-CAN | 1.42 | 完成 |
| E14 | 神经网络跨库 | PURE → UBFC 全集 | DeepPhys | 1.26 | 完成 |
| E15 | 神经网络跨库 | PURE → UBFC 全集 | EfficientPhys | 2.68 | 完成 |
| E16 | 神经网络跨库 | PURE → UBFC 全集 | PhysFormer | 1.38 | 完成 |

## 说明

- **E11**：7 个传统方法在 CPU 上跑，FFT 估计心率。投影/色度类 CHROM（3.31）、POS（3.52）最好；ICA / PBV / LGI / OMIT / GREEN 在难样本上大幅退化（15–23 bpm）。排序与文献一致。
- **E12–E16**：用 PURE 上训练的发布权重（`final_model_release/`）在 UBFC 全集上跨库推理，本机不训练。全集让模型之间有了区分度：DeepPhys（1.26）/ PhysFormer（1.38）/ TS-CAN（1.42）领先，PhysNet 与 EfficientPhys 约 2.68。神经网络整体明显优于无监督。
- **EfficientPhys 异常已解决**：子集上 MAE 16.04、Pearson −0.14（曾标"异常待查"）；全集上 MAE 2.68、Pearson 0.867，完全正常。确认那是 n=4 下"负相关≈噪声"的小样本假象，不是模型或推理归一化问题。

## MR-NIRP 车载试点（E21–E36）

2026-06-28 的第一批车载数据。MR-NIRP Car（驾驶场景，近红外 + RGB 双相机），工具箱无加载器，自写 `scripts/mrnirp/MRNIRPLoader.py`。PURE 预训练跨库推理，NIR 与 RGB 两个通道各跑无监督 + 5 个神经网络。汇总见 [`../reports/baseline_benchmark/mrnirp_pilot_summary.md`](../reports/baseline_benchmark/mrnirp_pilot_summary.md)，原始指标 [`mrnirp_metrics.json`](mrnirp_metrics.json)。

数据为**部分下载**。清掉损坏/残片、从官方 Drive 补齐缺失真值后，**可用 video+GT 为 NIR n=23、RGB n=29**（覆盖 Subject 1/3/10/11/14–19）；每会话截前 ~150 s，FS=30（NIR 由 ~60 fps 抽帧到 30）。审计清单见 [`../reports/baseline_benchmark/mrnirp_unusable_list.txt`](../reports/baseline_benchmark/mrnirp_unusable_list.txt)。

| ID | 通道 | 方法 | 最好 MAE (bpm) | 状态 |
|---|---|---|---:|---|
| E21 | NIR | GREEN（NIR 单通道只有 GREEN 有效） | 24.2 | 完成 |
| E22–E26 | NIR | PhysNet / TS-CAN / DeepPhys / EfficientPhys / PhysFormer | 22.1–28.2 | 完成 |
| E31 | RGB | POS / CHROM / ICA / GREEN / LGI / PBV / OMIT | POS 13.96 | 完成 |
| E32–E36 | RGB | PhysNet / TS-CAN / DeepPhys / EfficientPhys / PhysFormer | PhysFormer 17.77 | 完成 |

- **实验室→车载断崖式掉点**：同方法 UBFC 全集 MAE ~1–3.5、MACC ~0.8 → 车载 RGB MAE ~14–33、MACC ~0.15。
- **RGB ≫ NIR**：单通道 NIR 上方法基本失效（色度类复制成 3 通道即退化，仅 GREEN 有意义但仍 MAE ~24，Pearson≈0）；RGB（颜色被近红外照明污染）仍保留可用脉搏，最好 POS 13.96。
- **车载里传统 > 深度**：POS/CHROM（13.96/14.16）反超所有 PURE 预训练网络（最好 PhysFormer 17.77）；EfficientPhys 又最差（33.38），与 UBFC 上"最敏感"一致。
- **结论稳健**：样本从最初偏向 Subject1 的 14/23 扩到更均衡的 23/29 后，排序与量级不变。
- 注意：缓存不入库，放数据盘 `processed/MRNIRP_{NIR,RGB}_*`。

## 重跑

```bash
# UBFC 全集基准（后台串行跑完，可退出登录继续）
bash scripts/repro/run_full_ubfc.sh

# MR-NIRP 车载试点（两通道全套；先 install_into_toolbox.sh 注入加载器）
bash scripts/mrnirp/run_mrnirp_pilot.sh

# 单个实验（run_one.sh 会 cd 进工具箱，配置路径必须用绝对路径）
bash scripts/repro/run_one.sh E11_unsup_UBFCfull /home/lsg/rPPG/configs/repro/UBFC_full_UNSUPERVISED.yaml
python scripts/repro/parse_metrics.py logs/<日志>.log --kind unsupervised|neural --label <名称>
```
