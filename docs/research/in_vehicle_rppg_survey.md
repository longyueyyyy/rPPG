# 车载摄像头 rPPG：综述与可执行的数据集获取矩阵

*项目：面向车内驾驶员健康监测的稳健摄像头远程光电容积脉搏波（rPPG）。底座为 [rPPG-Toolbox（NeurIPS 2023）](https://arxiv.org/pdf/2210.00716)。文档日期：2026-06-02。处于复现阶段的数据集选型，约 22 GB 空闲磁盘，可能为中国大陆网络环境。*

---

## 1. 问题定位：车载 rPPG 为何困难

在静止、光照良好的实验室基准上，rPPG 基本"已被解决"——UBFC-rPPG 与 PURE 上心率 RMSE 约 **1.0 bpm**。但同样的流水线一进入行驶中的车厢就崩溃，因为各种失效模式同时攻击心搏信号。对这种崩溃最清晰的单一量化来自 [Lee 等人，IEEE TITS 2025](https://ieeexplore.ieee.org/abstract/document/10818975)：rPPG 的 RMSE 从**室内约 1.0 bpm 上升到车内超过 9.07 bpm**，"由运动相关伪影与环境光照波动引起"，且 **PTE6 仅约 65.1%**（心率误差小于 6 bpm 的时间占比）。各项驾驶特有失效模式，均有独立量化：

- **头/身体运动——最主要的误差来源，误差大致翻倍。** 在真实的 [MR-NIRP 驾驶基准](https://arxiv.org/html/2411.00919v1) 上，某 NIR 深度学习方法从 **7.5 bpm MAE（头部静止）→ 16.6 bpm（轻微头部运动）**；信号处理方法 DIS 在驾驶运动下平均为 RGB 6.5 bpm / NIR 15.9 bpm，且基于物理的方法比深度学习更稳健。在 [MMPD 压力数据集](https://arxiv.org/pdf/2302.03840) 上，**行走是普遍的最差情形**——"没有任何模型在最难的行走运动下表现良好"，全集有监督 MAE 为 **9.47–20.78 bpm**，而匹配的静止数据上低于 1 bpm。

- **说话——真实但较小的代价。** 非刚性的嘴/下颌形变在心率频带注入噪声。在 [PhysDrive](https://arxiv.org/html/2507.19172v1) 上，静止→说话使 PhysMLE-RGB 的心率 MAE 从 **6.55 → 6.98**、PhysNet-NIR 从 **10.35 → 11.13 bpm**。

- **动态/突变/低照度——比稳定光照更差，夜间最差。** [PhysDrive](https://arxiv.org/html/2507.19172v1)（RhythmNet）报告 MAE：**正午 8.87 / 黄昏黎明 7.91 / 雨天多云 8.40 / 夜间 11.96 bpm**，其中波动的方向性光照危害最大。[DLCN 夜间数据集](https://arxiv.org/html/2507.04306v1)（98 名受试者，瞬时亮度变化场景，类比隧道/阳光闪烁）显示 PhysFormer 从 **1.28 bpm（稳定光照+姿态）→ 5.34 bpm（变化光照+变化姿态）**。

- **高心率——结构性失效，而非边缘工况。** 在 [CHILL 研究（npj Digital Medicine 2025）](https://www.nature.com/articles/s41746-025-02192-y)（心率 54–141 bpm）中，**8 种算法中有 5 种在高心率下显著退化**，而低照度相对影响较小；经典 POS/CHROM 在分布外胜过深度学习。机理：约 90–100 bpm 以上时，心搏频带在功率谱上与呼吸/运动重叠，且数据集对高心率代表性不足。

- **单波长 NIR 以低信噪比换取光照不变性。** [PhysDrive](https://arxiv.org/html/2507.19172v1)：最佳 RGB 为 **6.29 bpm（PhysNet）**，最佳 NIR 为 **10.69 bpm**；[MR-NIRP](https://arxiv.org/html/2411.00919v1)：DIS 为 RGB 6.5 bpm vs NIR 15.9 bpm。NIR 对夜间是必需的，但结构上更嘈杂。

- **道路振动与遮挡——已量化的次要模式。** [PhysDrive](https://arxiv.org/html/2507.19172v1) 报告颠簸路面使 MAE 增加 **约 13%**（拥堵小于 5%）。[戴口罩下的远程脉搏估计](https://arxiv.org/pdf/2101.04096) 报告布质口罩使心率 MAE **上升超过 80%**；眼镜遮挡眼周/鼻部 ROI。关键地，[RobustPPG（Biomed. Opt. Express 2022）](https://pmc.ncbi.nlm.nih.gov/articles/PMC9664884/) 表明当振动频率与心率频带重叠时，**仅凭像素强度无法恢复信号**——这是一个根本性物理极限，构成 IMU/毫米波融合的动机。

文献记载的最强缓解手段，直接构成本项目架构的动机：**带拒绝的质量/不确定性门控**（[Lee TITS 2025](https://ieeexplore.ieee.org/abstract/document/10818975)：质量最高的前 10% 片段达到 **91.98% PTE6**，而整体为 65.1%）、**多模态融合**（[PhysDrive](https://arxiv.org/html/2507.19172v1)：毫米波 mmFormer **3.65 bpm** 优于最佳 RGB 6.29 bpm）、**多波长 NIR**，以及**自适应频谱方法**（[Huang 等人，IEEE JBHI 2021](https://pubmed.ncbi.nlm.nih.gov/32970601/)：在 23 小时驾驶数据库上，轿车乘员/紧凑型车/公交分别为 3.43/7.85/5.02 bpm MAE）。

---

## 2. 2022–2026 技术现状：稳健性与泛化

技术现状分为三大流派，且**没有任何单一架构在跨域上占优**。

**(1) 高精度有监督架构**——PhysNet、TS-CAN/EfficientPhys、[PhysFormer/PhysFormer++（IJCV 2023）](https://arxiv.org/abs/2302.03548)、[RhythmFormer（Pattern Recognition 2025）](https://arxiv.org/html/2402.12788v1)、[RhythmMamba（AAAI 2025）](https://arxiv.org/abs/2404.06483)/[PhysMamba](https://arxiv.org/abs/2409.12031)、[FactorizePhys（NeurIPS 2024）](https://arxiv.org/abs/2411.01542)。它们在数据集内部领先，但**跨域时崩溃**：在 [rPPG-Toolbox 基准](https://arxiv.org/pdf/2307.12644) 上，TS-CAN 从 **PURE 上 1.07 MAE / ρ 0.97 → MMPD 上 12.59 MAE / ρ 0.23**；DeepPhys 1.15 → 12.71；EfficientPhys-C 2.59 → 13.39。值得注意的是，**更轻的模型往往与重型 Transformer 泛化得一样好**（EfficientPhys-C 的跨数据集一致性强于 PhysFormer），且合成→真实存在很大差距（PhysFormer 在 SCAMPS 上训练后于 PURE 得到 26.58 MAE，而在真实 UBFC 上训练为 12.92）。最可靠有效的技术：时间差分建模、频域损失（Wasserstein 功率谱对齐、标签分布学习），以及周期性稀疏注意力（RhythmFormer）/ 基于 NMF 的注意力（FactorizePhys FSAM）。

**(2) 显式域泛化**——[NEST（CVPR 2023）](https://arxiv.org/abs/2303.05955)（特征覆盖最大化，首个 DG 基准）、[HSRD（JBHI 2024）](https://ieeexplore.ieee.org/document/10371379/)（风格/实例解耦，优于 NEST）、[ND-DeeprPPG（TIP 2023）](https://ieeexplore.ieee.org/document/10314460/)（利用背景参考做对抗-CCA 的环境噪声解耦）、[PhysMLE（TPAMI 2025）](https://arxiv.org/abs/2405.06201)（低秩专家混合，多任务 HR/RR/SpO2），及其后续 [GAP（IJCV 2025）](https://arxiv.org/pdf/2506.16160)（增加测试时个性化，在 VIPL-HR 上比 PhysMLE 好约 10–13%）。注意：通用 DG 方法（SAM/DomainGS）在 rPPG 上常因域冲突而**没有**增益。

**(3) 自监督/弱监督 + 测试时自适应**——[Contrast-Phys+（TPAMI 2024）](https://arxiv.org/abs/2309.06924)（时空对比，即使部分/无标签也稳健）、[Bi-TTA（ECCV 2024）](https://arxiv.org/abs/2409.17316)（首个面向 rPPG 的无源测试时自适应）、[PhysRAP（ACM MM 2025）](https://arxiv.org/abs/2510.01282)（持续测试时自适应，冻结生理参数以抵抗在时变天气/光照下的遗忘——与隧道/阳光闪烁/昼夜切换直接类比）。[PhysDrive](https://arxiv.org/pdf/2507.19172) 作者明确建议**无监督预训练 + 有监督微调**，因为有监督深度学习在车内泛化很差。

**部署上仍未解决的问题：**(a) 夜间/低光需要 NIR，但 NIR 信噪比低；(b) 振动频率与心率重叠是纯相机感知的物理极限；(c) 可信的逐窗口质量/不确定性 + 拒绝尚不成熟（见第 4 节）；(d) 持续的非平稳域漂移；(e) 肤色多样性（MMPD：Fitzpatrick 4–6 把 MAE 推高到 10 bpm 以上）；(f) STMap 流水线在车载嵌入式算力上的实时延迟。

---

## 3. 面向夜间/低光驾驶的 NIR 与 RGB-NIR 融合

夜间与低光驾驶使 RGB rPPG 不可用（车厢照明崩溃，车灯/路灯闪烁占主导），因此 **NIR 是实现光照不变性的标准硬件方案**——但伴随实实在在的精度代价。这一权衡在各数据集上一致：NIR 换来光照不变性却损失信噪比，得到的 rPPG **明显差于 RGB**（[PhysDrive](https://arxiv.org/html/2507.19172v1)：最佳 NIR 10.69 vs 最佳 RGB 6.29 bpm；[MR-NIRP](https://arxiv.org/html/2411.00919v1)：DIS 为 RGB 6.5 vs NIR 15.9）。[MMDrive（CVPRW 2025）](https://openaccess.thecvf.com/content/CVPR2025W/ABAW/papers/Choi_MMDrive_Multi-modal_Remote_Physiological_Signal_Measurement_Dataset_for_Driver_Status_CVPRW_2025_paper.pdf) 采用 NIR，正是因为 RGB"对光照变化高度敏感"。

两种推荐的补救方案：

1. **多波长 NIR**——MR-NIRP 基准作者称，从单波长转向多波长 NIR（如 940 nm + 975 nm）是"迈向稳健"车载心率的关键一步。[Ivrr-PPG（IEEE 2023）](https://ieeexplore.ieee.org/abstract/document/10113355) 使用带主动 NIR 照明的 940 nm NIR 相机与二色照明模型来应对剧烈变化的车厢光照——这是本项目 NIR 分支的一个具体设计范式。

2. **双 RGB-NIR 深度融合**——[基于深度学习的彩色与 NIR 驾驶场景 rPPG 测量](https://scholar.nycu.edu.tw/en/publications/deep-learning-based-remote-photoplethysmography-measurement-in-dr/) 报告通过双 RGB/NIR 模型在带昼/夜/雨测试集上**夜间 RMSE 提升最高达 42.6%**。自然的架构是白天以 RGB 为主、夜间以 NIR 为主，由质量信号（第 4 节）仲裁切换——并以毫米波雷达作为当两种相机模态都因振动退化时的非相机后备（[PhysDrive](https://arxiv.org/html/2507.19172v1) mmFormer 3.65 bpm）。

---

## 4. 质量/不确定性/拒绝：已有工作与创新空白

用于质量门控拒绝层的文献分散在三个互不相连的层面——真正的创新在于**在真实驾驶分布漂移下把它们缝合起来**。

**(1) 信号质量指数（SQI）。** [Elgendi 等人（npj Biosensing 2024）](https://www.nature.com/articles/s44328-024-00002-1) 是 rPPG SQI 的奠基工作：在 124 个会话上测试了六种指数（灌注、峰度、偏度、过零率、熵、信噪比），选出信噪比指数 **NSQI，并给出可部署的门控阈值 < 0.293**，以心率 MAE 和 Mann-Whitney U 验证。Kraft 等人（PETRA 2023）通过 1D-UNet 给出 [0,1] 的可靠性因子。[iBVP 数据集（Electronics 2024）](https://github.com/PhysiologicAILab/iBVP-Dataset) 提供逐窗口质量标签与形态学感知的 **MACC** 指标，且已接入 rPPG-Toolbox。

**(2) 不确定性量化。** [BeliefPPG（UAI 2023）](https://proceedings.mlr.press/v216/bieri23a/bieri23a.pdf) 给出经典的选择性预测结果：拒绝最不确定的前 1% 预测可降低 MAE 4%，前 5% 降低约 15%（将心率建模为带置信传播的 HMM；以 NLL 校准）。[RF-BayesPhysNet（2025）](https://arxiv.org/abs/2504.03915) 是首个对偶然+认知不确定性建模的贝叶斯 rPPG 网络，带 rPPG 专用指标（不确定性-误差 Spearman 相关、预测区间覆盖率、置信区间宽度）——但仅在干净的 UBFC 上验证，且只在低噪声场景下表现良好。

**(3) 选择性/共形预测。** 分裂共形给出无分布假设的覆盖保证，但其可交换性假设被驾驶时间序列违背；近期理论（Barber–Pananjady 2025）与在线方法（DtACI）在时间依赖下对覆盖率给出界/修复。

**创新空白：** 尚无人将*经校准的 rPPG 质量/不确定性信号*与*共形选择性预测层*结合，在**真实驾驶漂移（运动、NIR/夜间、阳光闪烁）下报告心率的覆盖-风险曲线与选择性 MAE**。最直接的驾驶基线仍是 [Lee TITS 2025](https://ieeexplore.ieee.org/abstract/document/10818975)（基于质量的补偿把驾驶 PTE6 提升到 68.24%）。可部署的目标指标：覆盖率下的选择性 MAE/RMSE（风险-覆盖曲线、AURC）、心率校准的 ECE/NLL/可靠性图、预测区间覆盖率+宽度，以及逐窗口拒绝率。**rPPG-Toolbox 已自带一个 NeuroKit2 模板匹配/相异度 SQI，带 `reject < 0.5` 门控（PhysDriveLoader），外加 SNR+MACC 评估**——这是可在其上扩展、而非从零构建的现成基线。

---

## 5. 数据集获取矩阵

凡综述发现与独立核实结果相左之处，**以核实结果为准**（已在表中标注）。两处尤为关键的更正：**CHILL 并非可直接开放下载——它是受限的（需 EULA + 邮件审批，Zenodo 为受限存档，已发布 23 名受试者而非 45 名）**；**UBFC-rPPG 更应描述为可直接公开下载的 Google Drive，而非需表单/申请的受限获取**。

| 数据集 | 是否发布 | 获取方式 | 体量 | 模态 | 真值 | 中国可达性 | 推荐用途 |
|---|---|---|---|---|---|---|---|
| **PhysDrive** | 是（NeurIPS 2025） | 两档：(1) **预处理子集，Kaggle，无需协议** [链接](https://www.kaggle.com/datasets/xiaoyang274/physdrive)；(2) **完整原始数据——邮件** xyang856@connect.hkust-gz.edu.cn，签数据共享协议。[仓库](https://github.com/WJULYW/PhysDrive-Dataset) | 完整原始约 24 小时 / 约 150 万帧，**数十至上百 GB**。Kaggle 子集小得多（1 名原始受试者 + 预处理的毫米波） | **RGB + NIR + 原始毫米波**（3 路同步非接触） | **ECG、BVP、RESP、HR、RR、SpO2**（6 种） | **混合/有利**——作者在中国大陆；**邮件路径是对中国最稳的方式**。Kaggle 常需 VPN | **最相关的车载目标。** 覆盖全部干扰因素 + 全部模态 + 丰富标签，且与工具箱兼容。*磁盘提示：完整原始超过 22 GB——先用 Kaggle 子集或定制的原始子集。* |
| **MR-NIRP Driving（Rice/MERL）** | 是 | **可直接公开下载的 Google Drive**，见 [Rice 页面](https://computationalimaging.rice.edu/mr-nirp-dataset/) → [Drive 文件夹](https://drive.google.com/drive/folders/1U3fzIOESmaBAyikGF0cKI2wW3YK8JqCK)。仅需引用，无表单 | 190 段视频 / 19 名受试者，中等体量（小于 PhysDrive 原始） | **RGB + NIR**（940 与 975 nm）。无毫米波 | 仅**脉搏血氧仪（PPG）**；无 ECG/SpO2 | **无 VPN 较差**——Google Drive 在中国大陆被屏蔽 | 低门槛的真实驾驶 NIR 后备（昼/夜）。获取 **DRIVING** 集（区别于较老的室内 MR-NIRP）。中国需 VPN |
| **MMDrive** | **否——已核实未发布（2026-06）** | **不存在获取机制。** [仓库](https://github.com/ziiho08/MMDrive) 仅有 LICENSE+README，"Access and Usage"为空，自 2025-04 起标"即将发布"；存在一个未回复的数据发布 issue。可邮件 CVPRW 2025 作者（Choi 等人） | 未发布 | RGB + NIR（仅相机） | 接触式 PPG | 不适用（无可下载内容） | **复现不要依赖它。** 关注/收藏仓库；仅作未来补充 |
| **UBFC-rPPG（42 名）** | 是 | **核实：可直接公开下载的 Google Drive，未受限。** [Sites 页面](https://sites.google.com/view/ybenezeth/ubfcrppg) → [公开 Drive 文件夹](https://drive.google.com/drive/folders/1o0XU4gTIo46YfwaWjIgbtCncc-oF44Xk)（DATASET_2）。仅需引用，无需邮件。[Kaggle 镜像](https://www.kaggle.com/datasets/malekdinarito/ubfc-rppg-dataset) | **约 3–5 GB** | 仅 RGB | 接触式 PPG + HR（CMS50E） | **经 Drive 有问题（被屏蔽）；用 Kaggle 镜像**（可达，免费账号） | **首次复现的主力 RGB 数据集。** 工具箱默认。能对标已发表心率数字的最小真实视频集 |
| **PURE（10 名）** | 是 | **受限——邮件** nikr-datasets-request@tu-ilmenau.de；签协议后给私有链接。[页面](https://www.tu-ilmenau.de/en/university/departments/department-of-computer-science-and-automation/profile/institutes-and-groups/institute-of-computer-and-systems-engineering/group-for-neuroinformatics-and-cognitive-robotics/data-sets-code/pulse-rate-detection-dataset-pure) | 约 6–10 GB | RGB（PNG 帧序列） | PPG + SpO2 + HR（JSON） | **可达**（德国大学服务器，无需 VPN）；唯一阻力是邮件审批延迟 | 第二个核心工具箱数据集。有显式的头部运动/说话设置 → 早期运动稳健性检验 |
| **MMPD** | 是 | **受限——需教职工签署协议** 发至 tjk24@mails.tsinghua.edu.cn（抄送 yuntaowang@），主题"MMPD Access Request - <机构>"。[仓库](https://github.com/McJackTang/MMPD_rPPG_dataset)。*用 tjk24@，不要用过期镜像的 tjk19@* | 完整 **370 GB**；**Mini 48 GB**（80×60） | RGB（手机，.mat） | PPG + 8 项条件标签（光照/运动/肤色/眼镜…） | **对中国完全友好**——百度网盘 + 硬盘寄送方案；需教职工邮件 | 关键的复杂条件压力测试（运动/光照/肤色/眼镜）。**用 Mini 48 GB。** 预留审批时间。*Mini（48 GB）远超 22 GB 空闲——需先扩容磁盘* |
| **CHILL（45→已发布 23）** | 是——**但受限，非直接开放（核实更正综述）** | **EULA + 邮件审批。** 在[此处](https://uni-bielefeld.sciebo.de/s/EsaD7YsnoNykj2s)下载 EULA，签署后在 [Zenodo](https://zenodo.org/records/14637544) 上"Request access"，和/或邮件 bhargav.acharya@uni-bielefeld.de。`access_right: restricted`，`files: []` | 小（约几 GB；**36×36** 匿名化帧） | RGB 36×36 + 接触式 PPG | 接触式 PPG（HR 54–141 bpm） | **可达**（Zenodo/CERN），但**需先通过 EULA 审批** | 高心率 + 低光评估目标。已发布 **23 名同意的受试者**（非 45）。36×36 分辨率太低，不能训练——仅评估。无驾驶 |
| **iBVP（RGB-热成像）** | 是 | **受限——需导师签署 EULA** [PDF](https://github.com/PhysiologicAILab/iBVP-Dataset/raw/main/assets/EULA_iBVP-Dataset.pdf) 邮件发至 jitesh.joshi.20@ucl.ac.uk + youngjun.cho@ucl.ac.uk → 个人链接 | **约 400 GB** | RGB + **热成像**（FLIR A65SC） | 耳部 PPG（BVP）+ **内置质量标签** + 灌注指数 | 受限/缓慢；交付主机未指明（可能需代理） | **与质量/不确定性目标最相关**（含质量标签）+ 热成像夜间代理。但 400 GB + 受限 → 非首选 |
| **UBFC-Phys（56 名）** | 是 | **仅需免费 IEEE 登录**（核实：非付费订阅）。[IEEE DataPort](https://ieee-dataport.org/open-access/ubfc-phys-2)，登录后下载 s1–s56.zip。镜像：search-data.ubfc.fr（TLS 不稳定） | 原始 **约 700 GB–1 TB** | RGB + Empatica E4（腕带） | 腕部 BVP + EDA + 焦虑评分 | IEEE DataPort 可达；免费账号门槛 | 说话任务（T2）适合做说话伪影检验。优先级低于 UBFC-rPPG/PURE；非常大 |
| **SCAMPS（合成）** | 是 | **直接 HTTP（Azure），无需登录。** [仓库](https://github.com/danmcduff/scampsdataset)；完整 600 GB / **1.2 GB 示例**压缩包 / 仅标签 60–500 MB | 完整 **600 GB**；示例 **1.2 GB** | 合成 RGB + 掩膜 | 精确的合成 PPG/BVP + 呼吸 | **可达**（Azure CDN，非 Drive）；阻碍仅在体量 | 合成预训练/域随机化来源。**只取 1.2 GB 示例。** 不能替代真实视频 |

---

## 6. 推荐方案

### (a) 首次复现的单一最佳数据集（约 22 GB 空闲，可能为中国网络）

**经 Kaggle 镜像获取 UBFC-rPPG。** 它是 rPPG-Toolbox 默认数据集，约 3–5 GB（远低于 22 GB），是能复现已发表心率数字的真实 RGB 视频；对中国网络至关重要的是，[Kaggle 镜像](https://www.kaggle.com/datasets/malekdinarito/ubfc-rppg-dataset) 无需 VPN 即可访问，而官方 Google Drive 不行。立即搭配 **PURE**（并行发邮件申请，约 6–10 GB，德国服务器可达，增加说话/头部运动设置），使第一个跨数据集泛化实验（UBFC 训练 → PURE 测试）即对齐工具箱的经典协议。

为何首次复现不选其他：PhysDrive 完整原始、MMPD-Mini（48 GB）、iBVP（400 GB）都超出或紧逼 22 GB；CHILL 与 MMDrive 受限/未发布，今天无法下载；MR-NIRP 的 Google Drive 主机在中国被屏蔽。UBFC-rPPG 是唯一小巧、真实、对中国可达、且**现在**就能零审批延迟下载的选择。

### (b) 通往车载数据的三步获取优先计划

1. **现在——在用 UBFC-rPPG + PURE 复现的同时，并行启动审批周期最长的受限申请。** 给 PURE 发邮件（nikr-datasets-request@tu-ilmenau.de），并由**教职工**发送 MMPD 协议（tjk24@mails.tsinghua.edu.cn，抄送 yuntaowang@；申请 **48 GB Mini** + 百度/硬盘的中国交付方式）。这些审批需数天至数周；第一天就启动。可用约 1.2 GB 的 SCAMPS 示例做一次可选的合成预训练冒烟测试。

2. **获取主力车载目标——PhysDrive——走作者邮件路径。** 这是项目的主复现数据集（RGB+NIR+毫米波，6 种真值，覆盖全部驾驶干扰因素，且与工具箱兼容）。在中国网络下，**邮件 xyang856@connect.hkust-gz.edu.cn 申请签协议的原始数据共享**（对中国更稳，避开依赖 VPN 的 Kaggle 路径）。为尽快、省磁盘地起步，先拉取 **Kaggle 预处理子集**（1 名原始 RGB/NIR 受试者 + 预处理毫米波）以在完整原始数据到来前先把加载器接通。若完整原始放不下 22 GB，则协商一个**定制的原始子集**。

3. **补充 NIR/夜间驾驶的广度：现在用 MR-NIRP，待 MMDrive 发布后再加。** 获取 **MR-NIRP Driving**（真实昼/夜 RGB+NIR，19 名受试者）——中国需经 VPN 或境外镜像——作为补充 PhysDrive NIR 的早期 NIR/低光验证集。**关注/收藏 MMDrive 仓库**并为其数据发布 issue 点赞；严格视其为未来补充（截至 2026-06 未发布，且仅相机，故并不提供 PhysDrive 所缺内容）。对高心率 + 低光*评估*，提交 **CHILL EULA**（签署 → 邮件 bhargav.acharya@uni-bielefeld.de）作为仅用于基准的目标。

---

## 7. 对研究计划的修订建议

重新编排计划，使受限/长周期申请（PURE、MMPD 教职工协议、PhysDrive 原始数据共享、CHILL EULA）在第一天就*并行*发出，同时当天即用 UBFC-rPPG（Kaggle）+ PURE 开始复现，而非串行——真正的关键路径是审批延迟，而非下载速度。把车载工作锚定在 **PhysDrive 作为唯一主目标**（它独有地覆盖每种失效模式外加 RGB/NIR/毫米波，且已接入工具箱），将 **MR-NIRP** 作为 NIR/夜间补充，并明确**将 MMDrive 移出关键路径**（已核实未发布，且仅相机）。对于创新贡献，把工具箱*现有*的 PhysDriveLoader SQI/`reject<0.5` 门控扩展为**经校准的质量 + 共形选择性预测头**，报告风险-覆盖/AURC、ECE/NLL，以及驾驶漂移下的选择性 MAE——这正是第 4 节的真实空白——并在领域测试不足的压力轴上验证它：**行走/高心率（MMPD、CHILL）、夜间/NIR（MR-NIRP、PhysDrive-NIR）、道路振动（PhysDrive 颠簸 + 毫米波后备）**。谨慎规划磁盘：PhysDrive 完整原始、MMPD-Mini（48 GB）、iBVP（400 GB）都超出 22 GB 余量，因此在投入前请规划定制子集或分级存储。
