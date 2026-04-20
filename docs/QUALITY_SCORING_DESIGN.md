# 鸟类摄影质量评分 —— 技术设计（待实现）

> 状态：**设计冻结待实现**。Stage 3 当前实现用简单版跑通 cull 流程，质量评分维度仍走单一 overall 分。本设计文档为后续"大力做质量评分"阶段的权威蓝图。
>
> 最后一次更新：2026-04-20。

---

## 一、为什么质量评分是核心

观鸟 cull 流程的灵魂不是"鸟清不清楚"，是**"眼睛清不清楚"**。

- 羽毛 90% 锐、眼睛糊 → 废片。
- 羽毛 70% 锐、眼睛 catch light 到位 → 杂志封面。
- 一只麻雀在 6000px 全画幅里眼睛只有 4–8 px，但它决定这张照片的生死。

通用 culling 工具（Lightroom AI Cull、Photo Mechanic、甚至前身 Kestrel）把整只鸟当一个区域统一评分，**把摄影师脑子里最关键的那根弦抹平了**。这是 Birder Studio 的差异化护城河。

---

## 二、Kestrel 的做法（前身 Python 项目）复盘

一句话管线：
**Mask R-CNN 鸟分割 → 鸟 mask 区域内 Sobel 梯度 → Keras 质量小模型 → 库内 CSV percentile 归一 → 单一标量分 (0–1)**

### 好的地方

1. **区域化评分**：只在鸟 mask 里算，不被糊的背景拖死 (`analyzer/kestrel_analyzer/ml/quality.py:68-75`)
2. **库内 percentile 归一**：原始模型输出经 CSV 查表变相对百分位 (`ml/quality.py:41-65`)，用户看到的星级是相对自己这一批，不是绝对标杆
3. **曝光预补偿**：在鸟区测光做 EV 调整后再打分 (`exposure_compensation.py:98-200`)，避免欠曝鸟被冤枉扣分
4. **混合去重**：timestamp ≤1s 直接判同 → AKAZE 特征匹配 (good matches/keypoints ≥0.05) → 颜色直方图兜底 (`similarity.py:82-131`)

### 缺的地方

1. **把整只鸟当一个区域**，眼睛/头/身体/尾羽平均起来打一个分
2. **Sobel 梯度是原始指标**，不分前景/背景、不分运动模糊 vs 对焦模糊
3. **没有眼睛关键点**
4. **单一质量分不可解释**：用户看到 3 星不知道是锐度扣分、曝光扣分还是构图扣分
5. **Mask R-CNN（168MB, PyTorch）在移动端太重**

---

## 三、Birder Studio 的方案（10x Kestrel）

**核心思想：不给一个质量分，给一个子分向量。** 每个子分对应鸟类摄影师脑子里的一条 checklist，独立归一、独立可查询、独立可过滤。

### 3.1 子分定义与权重

| 维度 | 权重 | 怎么算 |
|---|---|---|
| **眼睛锐度** | 50% | 检测眼睛关键点 → 32×32 patch → Laplacian + FFT 高频能量 + catch light 检测 |
| **头部锐度** | 20% | 喙尖到脖根区域的梯度 |
| **身体锐度** | 10% | 鸟 mask 的其余部分 |
| **运动 / 失焦判别** | 信号 | 模糊的方向性分析（各向异性 FFT）→ 区分抖糊（directional）还是对焦糊（isotropic）|
| **鸟区曝光** | 10% | 鸟 mask 内直方图；羽毛 clip %；特殊处理全白/全黑鸟（白鹭、乌鸦）|
| **构图** | 5% | 眼睛（非质心）vs 三分点；gaze direction headroom；鸟占画幅比例 |
| **背景干净度** | 5% | 鸟 mask 外显著性峰值（有没有抢镜树枝/杂物）|
| **姿态 / 光线加分** | bonus | 翅膀张开、回头、catch light、干净焦外 |

### 3.2 管线

```
[Photo]
   │
   ▼
[鸟分割]            YOLOv11-seg fine-tune 在 CUB-200/NABirds
   │                或 Grounded-SAM 蒸馏成 Core ML
   │                → bbox + polygon mask
   │
   ▼
[眼睛关键点]         在鸟 crop 上跑轻量 keypoint head
   │                → eye point(s) + head bbox + bill tip
   │
   ▼
[多区域锐度]         Metal shader
   │                → eye_sharp, head_sharp, body_sharp
   │
   ▼
[各向异性模糊分析]    方向性 FFT / Gabor 滤波器组
   │                → motion_vs_defocus signal
   │
   ▼
[鸟区曝光]           mask 内直方图 + clip 检测
   │                → exposure_score, clip_%
   │
   ▼
[gaze-aware 构图]    用眼睛位置+喙方向推朝向
   │                → composition_score, gaze_angle, headroom_px
   │
   ▼
[背景干净度]         mask 外显著性分析
   │                → bg_clean_score
   │
   ▼
[场景聚类]           VNImageFeaturePrint + 时间 gap
   │                → scene_id
   │
   ▼
[库内 percentile]    每个子分独立归一
   │
   ▼
[PhotoAnalysis 写库]
```

### 3.3 为什么这是"最好的"不是"最聪明的偷懒"

- **没人做"眼睛优先"**。Merlin 认物种，Lightroom AI Cull 看全局锐度，Kestrel 看整鸟。我们唯一做眼睛。
- **子分是透明的**。用户看到 3 星能点开看"哪儿扣分"——眼睛糊了？还是背景有根树枝？黑盒标量给不了这个。
- **分向量能排序能过滤**。"给我所有眼睛 ≥90 分位的" / "给我眼睛 ≥80 但背景 <50 的（精修候选）"——这是精修阶段的黄金查询。
- **跟随摄影师**。库内 percentile + 未来加入用户评分历史学习 → "我的 5 星"校准到个人审美。

---

## 四、撞硬墙前必须验的三件事（Probes）

**这些是现在在猜、不是在知道。** 架构锁定前必须跑 probe 验证。

### Probe 1：鸟分割模型选型

**问题**：YOLOv11-seg fine-tune vs Grounded-SAM 蒸馏 vs 自己标训 —— 速度 × 准度 × Core ML 转换成本三选二。

**方法**：拿 23 张 CR3 样本（`/Users/bruce.y/GitCode/ProjectKestrel/test_imgs/`），分别跑：
- YOLOv11-seg（COCO 版，bird 类）
- Grounded-SAM prompt="bird"
- Apple Vision `VNGenerateObjectnessBasedSaliencyImageRequest`（baseline）

**衡量**：mask IoU（目测）+ 推理时间（ms/张）+ 模型体积（MB）。

### Probe 2：小鸟眼睛定位

**问题**：麻雀类小鸟眼睛只有几 pixel，直接在原图上检测还是需要鸟 crop 上采样后再检测？现有开源 bird pose / keypoint 模型能不能直接用？

**方法**：
- 调研现成模型：MMPose bird configs、AnimalKingdom、CUB-200 landmark subset
- 在 23 张样本上人工标 eye point → 跑候选模型 → 算 PCK（Percentage of Correct Keypoints）

**衡量**：eye 点偏差 ≤4 px 的比例。

### Probe 3：锐度指标对比

**问题**：Laplacian 方差 vs FFT 高频能量 vs 各向异性分析，哪个最能区分"眼睛锐"和"眼睛糊"？

**方法**：在 23 张里人工挑"眼睛锐 vs 眼睛糊"配对（同一场景同一鸟的连拍），对每个指标跑 ROC，选 AUC 最高的组合。

---

## 五、Stage 架构 Hook（已预埋）

当前 Swift 代码已经给这套设计留了位置：

### 数据模型（`Sources/BirderCore/Models/PhotoAnalysis.swift`）

```swift
public struct QualityScores: Sendable, Hashable, Codable {
    public var overall: Double
    public var sharpness: Double          // 当前 stub 实现：Laplacian 全图
    public var exposure: Double           // 当前 stub 实现：直方图
    public var eyeSharpness: Double?      // ← 预留给未来眼睛锐度
    public var composition: Double?       // ← 预留给未来 gaze-aware 构图
    public var sessionPercentile: Double
}
```

### 管线协议（Stage 3 简单版实现时引入）

```swift
public protocol AnalysisPipeline: Sendable {
    func analyze(photoID: UUID, imageURL: URL, sessionID: UUID)
        async throws -> PhotoAnalysis
}

// 简单版（Stage 3 当前）
public struct SimpleAnalysisPipeline: AnalysisPipeline { ... }

// 鸟感知版（未来实现，对应本文档管线）
public struct BirdAwareAnalysisPipeline: AnalysisPipeline { ... }
```

`AnalysisService` 持有 `AnalysisPipeline` 作为依赖注入，切换实现零代码改动。

### 子分扩展

如果未来需要比 `QualityScores` 当前字段更细的子分，新增可选字段即可（`headSharpness`、`bodySharpness`、`bgClean`、`motionBlurSignal` 等），简单版读写时置 nil，鸟感知版填满。数据库迁移走 schema v2（在 Migrator 里加新列，NULL 允许）。

---

## 六、实施顺序

**当前阶段（Stage 3 简单版）**：
- 实现 `AnalysisPipeline` protocol
- 实现 `SimpleAnalysisPipeline`：Laplacian 全图锐度 + 简单曝光 + Vision feature print
- 跑通 cull 流程（rating、过滤、场景聚类）

**未来阶段（Stage 3+ 鸟感知版）**：
- 跑完上述 3 个 probe
- 锁定模型栈
- 分步实现本文档 §3.2 管线
- 数据库 schema v2 加子分字段
- UI 子分 inspector（detail view 里点开锐度看"哪儿扣分"）
- 按子分过滤 / 排序

---

## 七、参考

- Kestrel 源码：`/Users/bruce.y/GitCode/ProjectKestrel/`
  - 质量评分：`analyzer/kestrel_analyzer/ml/quality.py:68-86`
  - 相似度：`analyzer/kestrel_analyzer/similarity.py:82-131`
  - 曝光补偿：`analyzer/kestrel_analyzer/exposure_compensation.py:98-200`
  - 管线：`analyzer/kestrel_analyzer/pipeline.py:253-994`
- 样本：`/Users/bruce.y/GitCode/ProjectKestrel/test_imgs/`（23 张 CR3）
- 当前 PRD：`docs/PRODUCT_PLAN.md` / `docs/PRODUCT_PLAN_CN.md`
