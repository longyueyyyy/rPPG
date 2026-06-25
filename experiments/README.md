# 实验记录

每个实验一个目录 `E0*/`，里面固定三个文件：

- `config.yaml` —— 运行用的完整配置（含数据路径、预处理、评估方式）
- `environment.txt` —— 溯源信息：日期、Python / torch 版本、工具箱 commit
- `metrics.json` —— 该实验的指标

汇总指标在 [`all_metrics.json`](all_metrics.json)。运行日志（`run.log`）和保存的 BVP 波形输出体量大，不入库，留在服务器 `/home/lsg/rPPG` 上。

所有实验跑在同一环境：2026-06-02，conda 环境 `rppg`（Python 3.8.20，torch 2.1.2+cu118），4×RTX 3090，驱动 470 / CUDA 11.4，工具箱 commit `b7500b8`。数据是 UBFC-rPPG 的 4 名受试者子集 `{1, 3, 4, 5}`。

> **注意**：n=4 是简单条件（静止、光照良好）的小子集，只用于验证流水线正确性和方法相对排序。绝对指标不能和论文里 42 人全集的平均值比较。

## 实验清单

| ID | 类型 | 训练 → 测试 | 方法 | MAE (bpm) | 状态 |
|---|---|---|---|---:|---|
| E01 | 无监督 | 无训练 → UBFC 子集 | POS / CHROM / ICA / GREEN / LGI / PBV / OMIT | 0.22–9.89 | 完成 |
| E02 | 神经网络跨库 | PURE → UBFC 子集 | PhysNet | 0.88 | 完成 |
| E03 | 神经网络跨库 | PURE → UBFC 子集 | TS-CAN | 0.88 | 完成 |
| E04 | 神经网络跨库 | PURE → UBFC 子集 | DeepPhys | 0.88 | 完成 |
| E05 | 神经网络跨库 | PURE → UBFC 子集 | EfficientPhys | 16.04 | 异常，待查 |
| E06 | 神经网络跨库 | PURE → UBFC 子集 | PhysFormer | 0.88 | 完成 |

## 说明

- **E01**：7 个传统方法在 CPU 上跑，FFT 估计心率。POS / LGI / OMIT 最好（MAE 0.22），CHROM 次之（1.32），GREEN / ICA 最差（约 9–10）。这个排序与文献一致。
- **E02–E06**：用 PURE 上训练的发布权重（`final_model_release/`）在 UBFC 子集上跨库推理，本机不训练。PhysNet / TS-CAN / DeepPhys / PhysFormer 在这几段干净视频上落到同一个 FFT 心率频点，所以 MAE / RMSE / MAPE 完全相同，只有 SNR / MACC 有区别。
- **E05 EfficientPhys 异常**：MAE 16.04、Pearson -0.14。它是这组里对域偏移最敏感的模型，但 n=4 时负相关基本等于噪声。下一步在更多受试者上重测，并检查推理阶段的归一化，确认前不作结论。

## 重跑

```bash
bash scripts/repro/run_one.sh <实验ID> <配置文件绝对路径>
python scripts/repro/parse_metrics.py logs/<日志>.log --kind unsupervised|neural --label <名称>
```
