# 基线复现报告（rPPG-Toolbox 在本机的首次复现）

日期：2026-06-02
环境：conda 环境 `rppg`（Python 3.8.20，torch 2.1.2+cu118），4 张 RTX 3090，驱动 470 / CUDA 11.4。
工具箱 commit：`b7500b8`（ubicomplab/rPPG-Toolbox，2025-09-15）。
数据：UBFC-rPPG 的 4 名受试者子集 {1, 3, 4, 5}，取自 HuggingFace 镜像 `thachha901/UBFC`
（640×480，约 30 fps，真值为接触式 PPG 的 BVP）。人脸裁剪用 Haar Cascade，缩放至 72×72
（PhysFormer 为 128×128）。

注意（请先读）：以下结果基于 4 名受试者，而非完整的 42 人 UBFC-rPPG。因此 MAE/RMSE 的绝对值
不能直接与工具箱 Table 2（`external/rPPG-Toolbox/figures/results.png`）中 42 人的平均值对比；
在 n=4 时 Pearson 相关系数的统计意义也很弱。这次运行验证的是：(1) 整条流水线
（预处理 → 模型 → 心率/指标）在本机硬件与驱动上运行正确；(2) 方法之间的相对排序与文献一致。
扩充到 42 人全集（或更大的分层子集）以得到可发表的平均值，是已记录的下一步。

---

## 1. 传统无监督基线（无需训练）—— UBFC 子集，FFT 估计心率

| 方法 | MAE (bpm) | RMSE | MAPE % | Pearson r | SNR (dB) | MACC |
|---|---:|---:|---:|---:|---:|---:|
| POS   | 0.22 | 0.44 | 0.22 | 0.999 | -0.69 | 0.77 |
| LGI   | 0.22 | 0.44 | 0.22 | 0.999 | -1.38 | 0.70 |
| OMIT  | 0.22 | 0.44 | 0.22 | 0.999 | -1.38 | 0.70 |
| CHROM | 1.32 | 2.64 | 1.17 | 0.974 | -0.86 | 0.76 |
| PBV   | 3.52 | 7.03 | 3.12 | 0.756 | -2.31 | 0.65 |
| ICA   | 8.79 | 16.71 | 9.82 | 0.963 | -3.77 | 0.59 |
| GREEN | 9.89 | 16.91 | 10.80 | 0.943 | -3.32 | 0.59 |

解读：投影类/色度类方法（POS、LGI、OMIT、CHROM）明显领先；GREEN 与 ICA 最差。该排序与文献中
"在干净正脸视频上 POS/CHROM 远好于 GREEN/ICA"的结论一致。绝对 MAE 很低，是因为这 4 名受试者
属于简单条件（静止、光照良好）。

## 2. 预训练神经网络基线 —— PURE 到 UBFC（跨数据集，本机不训练）

权重来自 `final_model_release/`（在 PURE 上训练），在 UBFC 子集上测试。

| 模型 | MAE (bpm) | RMSE | MAPE % | Pearson r | SNR (dB) | MACC |
|---|---:|---:|---:|---:|---:|---:|
| PhysNet      | 0.88 | 1.76 | 0.99 | 0.996 |  0.09 | 0.81 |
| TS-CAN       | 0.88 | 1.76 | 0.99 | 0.996 |  0.40 | 0.83 |
| DeepPhys     | 0.88 | 1.76 | 0.99 | 0.996 |  0.45 | 0.82 |
| PhysFormer   | 0.88 | 1.76 | 0.99 | 0.996 | -0.76 | 0.76 |
| EfficientPhys | 16.04（异常） | 30.37 | 14.79 | -0.14 | -2.06 | 0.69 |

解读：PhysNet/TS-CAN/DeepPhys/PhysFormer 的 PURE 到 UBFC 跨库迁移都很好（MAE 0.88 bpm——在这
4 段干净视频上它们落到同一个 FFT 心率频点）。EfficientPhys 结果异常（MAE 16，负相关）。
EfficientPhys 是本组里对域偏移最敏感的模型，但在 n=4 时负相关基本等同于噪声，必须在更多受试者
上重新核验后才能下结论。已标记为待跟进项，暂不作为结论。

## 3. 溯源与可复现性

每个实验目录 `experiments/E0*/` 包含 `config.yaml`、`environment.txt`（python/torch/commit）、
`run.log` 与 `metrics.json`。汇总指标见 `experiments/all_metrics.json`。
已保存的 BVP 波形输出（供后续 SQI/波形分析使用）：
`external/rPPG-Toolbox/runs/exp/UBFC_subset_*/saved_test_outputs/*.pickle`。

重跑任意实验：
```bash
bash scripts/repro/run_one.sh <实验ID> <配置文件绝对路径>     # 例如 configs/repro/UBFC_subset_UNSUPERVISED.yaml
python scripts/repro/parse_metrics.py logs/<日志>.log --kind unsupervised|neural --label <名称>
```

## 4. 已知的后续事项

1. 扩充至完整/更大的 UBFC，得到可与 Table 2 对比的 42 人平均值。
2. 排查 EfficientPhys 在 PURE 到 UBFC 上的异常（增加受试者；检查推理阶段的归一化）。
3. 接入 CHILL（受限，需 EULA + 邮件审批；已发布 23 名受试者，仅供评估）做低光 / 高心率可靠性分析，见调研报告。
4. PhysDrive 车载数据需要加载器适配（HF 发布格式为 `RGB.mp4` + 会话 `AS/AT/...`，
   而工具箱加载器期望 `Align/*.png` + `A1/A2/...`）。
