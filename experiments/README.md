# 实验记录

每个实验一个目录 `E1*/`，里面固定三个文件：

- `config.yaml` —— 运行用的完整配置（含数据路径、预处理、评估方式）
- `environment.txt` —— 溯源信息：日期、Python / torch 版本、工具箱 commit
- `metrics.json` —— 该实验的指标

汇总指标在 [`all_metrics_full.json`](all_metrics_full.json)，可读的汇总表在 [`../reports/baseline_benchmark/full_ubfc_summary.md`](../reports/baseline_benchmark/full_ubfc_summary.md)。运行日志（`run.log`）体量大但仍留在各实验目录；约 74 GB 的预处理缓存不入库，放在数据盘 `/media/amdin/Drive1/rppg_data/processed/UBFC_full_*`。

所有实验跑在同一环境：2026-06-26，conda 环境 `rppg`（Python 3.8.20，torch 2.1.2+cu118），4×RTX 3090，驱动 470 / CUDA 11.4，工具箱固定 commit `b7500b8`。数据是 **UBFC-rPPG 全集（42 名受试者）**，整套约 40 分钟跑完。

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

## 重跑

```bash
# 整套全集基准（后台串行跑完，可退出登录继续）
bash scripts/repro/run_full_ubfc.sh

# 单个实验（run_one.sh 会 cd 进工具箱，配置路径必须用绝对路径）
bash scripts/repro/run_one.sh E11_unsup_UBFCfull /home/lsg/rPPG/configs/repro/UBFC_full_UNSUPERVISED.yaml
python scripts/repro/parse_metrics.py logs/<日志>.log --kind unsupervised|neural --label <名称>
```
