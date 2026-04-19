# Birder Studio — 实现规划 v0.1

> 从 PRD 到代码的桥梁。定义技术选型、架构、构建顺序、性能预算和质量底线。

本文档是 `PRODUCT_PLAN_CN.md` 的工程落地方案。PRD 回答"做什么"，本文档回答"怎么做 + 为什么这样做 + 怎么保证做到 10x"。

---

## 0. 执行摘要

**核心技术立场：**

1. **Swift 一等公民，不搭建桥接层。** 不用 Electron、不用 React Native、不用 Python+pywebview、不用 Flutter。全栈 Swift + 必要处的 Metal shader。
2. **Apple 原生 ML 栈，全本地推理。** 只用 Core ML + Vision Framework。目标检测、物种识别、质量评分**全部本地**，不走云端。不自训模型，用现成开源模型（iNaturalist / NABirds fine-tune 等），接受准确率上限换速度——2000 张照片本地推理 1-3 分钟，走云端要 20-60 分钟，不可接受。
3. **存储用 GRDB 不用 SwiftData。** SwiftData 尚年轻（rough edges 多、迁移难），GRDB 是成熟的 SQLite 封装，性能和可调试性都是专业级。
4. **图像处理用 Core Image + 关键路径自写 Metal。** Core Image 覆盖 90%，编辑器实时预览的关键 shader 自己写。
5. **并发用 Swift Concurrency + Actor。** 不用 GCD 裸写，不用 OperationQueue（除了互操作桥接）。
6. **最小目标 macOS 15 Sequoia+。** 不向下兼容 Intel Mac 或老系统——以此换 SwiftUI 5 / Vision 新 API / Swift 6 严格并发的能力上限。
7. **Bundle size 硬预算 < 150MB，v1 ML 模型总和 < 40MB。**
8. **性能为一级公民，不是后期优化。** 每个核心交互有明确 frame budget，CI 里跑基准测试回归。

这些选择背后的共同原则是：**用能做到的最上限的工具，不用大家都在用的那个**。

---

## 1. 技术栈决策（每一条都含拒绝理由）

### 1.1 UI 层：SwiftUI + AppKit/Metal 混合

**选择：** SwiftUI 作为主力，照片网格和编辑画布用 AppKit/MetalKit。

**为什么不纯 SwiftUI：** SwiftUI 的 `LazyVGrid` + `ScrollView` 在 5,000+ 缩略图场景下滚动卡顿、内存不可控。Apple 自己的 Photos.app 也用 AppKit 的 `NSCollectionView`。纯 SwiftUI 在**高密度图像网格**和**每帧重绘的编辑画布**这两个场景必定撞墙。

**为什么不纯 AppKit：** 窗口结构、侧边栏、Inspector 这类组合式布局 SwiftUI 写起来快 3 倍，动画系统成熟，声明式心智负担更低。

**混合边界：**
```
SwiftUI 负责：导航壳、侧边栏、Inspector、表单、设置、模态、过渡
AppKit 负责：PhotoGridView（NSCollectionView + NSCollectionViewCompositionalLayout）
MetalKit 负责：EditorCanvasView（CAMetalLayer + 自写 shader）
NSViewRepresentable 桥接这两处
```

**为什么不选 Electron / React / Flutter：** 不讨论。作为参考，ProjectKestrel 是 pywebview + HTML 方案，结果就是 12.5K 行前端代码 + 全套 Chromium 运行时打进 bundle。这条路我们不走。

### 1.2 存储层：GRDB.swift（不是 SwiftData，不是 Core Data）

**选择：** GRDB.swift（Gwendal Roué 写的 SQLite Swift 封装）。

**为什么不 SwiftData：**
- iOS 17+ 才有，macOS 14+ 同步，API 还在变（每个 Xcode 版本都有破坏性改动）
- 真实大数据量（10k+ 记录）下的性能问题多（启动时加载所有对象图）
- 调试工具弱——出错时你拿不到生成的 SQL
- 迁移语法未成熟，schema 演进时容易炸

**为什么不 Core Data：**
- API 设计是 2005 年的，Obj-C 遗产重
- Fault 机制和 Swift Concurrency 配合不好
- 过度工程化——我们不需要 Core Data 的能力

**为什么 GRDB：**
- 原生 SQL 可见、可控
- 性能基准：单次插入 100k 记录 < 2 秒
- 完全支持 Swift Concurrency（`DatabaseQueue.read { ... }` 可 await）
- 有 `GRDB.ValueObservation` 做响应式查询，直接接 SwiftUI
- 可以用 SQLite 的 FTS5 全文搜索，物种名模糊搜索直接免费拿到
- 生产级：使用它的 App 包括 Things、Mastodon、Pay 等

### 1.3 图像处理：Core Image + 关键路径 Metal Shader

**选择：**
- **全局使用 Core Image** 做 80% 的滤镜（曝光、白平衡、饱和度、锐化等）
- **自写 Metal shader** 做（a）编辑器画布的 per-frame 预览、（b）羽毛感知锐化、（c）主体感知暗角
- **ImageIO** 做 RAW 解码（CR2/CR3/NEF/ARW/DNG/RAF 原生支持），无需 LibRaw

**为什么不纯 Core Image：**
- Core Image 的链式 filter 在拖动滑块时会 per-frame 重构 CIImage 图，60fps 下 GPU 利用率抖
- 复杂的自定义操作（羽毛锐化需要边缘检测 + 自适应 unsharp mask）用 Core Image 写出来丑且慢

**为什么不 LibRaw：**
- ImageIO 已经覆盖所有主流鸟摄相机的 RAW 格式
- 多带一个 C 库增加编译复杂度、沙盒签名问题、二进制大小
- 只有在用户真的拍 Sigma Foveon 或冷门相机时才需要 LibRaw，v1 不考虑

### 1.4 ML 层：Core ML + Vision Framework（全本地，零云端）

**选择：** 全部本地推理，不走云端 API。

- **Apple Vision Framework** 做：前景蒙版分割（`VNGenerateForegroundInstanceMaskRequest`）、特征指纹去重（`VNGenerateImageFeaturePrintRequest`）、显著性辅助（`VNGenerateAttentionBasedSaliencyImageRequest`）、人脸/文字避让（用于智能水印位置）
- **Core ML** 做：鸟类 bbox 检测器（YOLO-v8 nano fine-tune 在 NABirds/iNaturalist → coreml 转换，约 6-10MB）、物种识别（EfficientNet-B2 或 ViT，iNaturalist 鸟类子集预训练 → coreml 转换，约 15-25MB）、质量评分（NIMA MobileNetV2，约 14MB）

**为什么全本地（不走云端）：**
- **速度：** 2000 张照片本地 Apple Silicon 推理 1-3 分钟；走云端 1-2 秒/张 = 20-60 分钟等待，毁掉"AI 后台处理"的核心承诺
- **离线可用：** 用户在野外、小木屋、自驾途中可能没网，本地 ML 全功能可用
- **零持续成本：** 云端调用每张 $0.02-0.05，批量用户月成本很重。本地一次编译永久免费。
- **隐私：** GPS 和照片都不离开设备

**为什么不自建模型 / 不做数据飞轮：**
- 见 `feedback_no_ai_accuracy_race.md`：不追 Merlin 准确率。这条在本地模型选择上同样适用。
- 用**现成的开源模型**：iNaturalist 2021/2024 竞赛 fine-tune 模型、NABirds 预训练权重、HuggingFace 上已有的鸟类分类器
- 准确率上限 80-90%（常见鸟种）vs Merlin 95%+，差距可接受——**用户修正就是修正，不做持续训练**
- 如果未来要更准，换更大的公开模型即可，不做自训

**地理覆盖是真问题（见 §10 开放决策）：**
- NABirds 模型覆盖北美 555 种，对北美用户 OK
- iNaturalist 鸟类子集约 900-1000 种，覆盖北美较全，欧洲其次，东亚不完整
- Bruce 自己在上海/崇明观鸟——中国/东亚鸟种覆盖是 v1 必须解决的问题，不是可延迟的

**为什么不 ONNX Runtime / PyTorch Mobile / TensorFlow Lite：**
- Apple 硬件上都跑不过 Core ML（缺 Neural Engine 支持）
- Bundle size 增加 10-20MB 没有换来任何能力
- Core ML 对 macOS 有深度集成（NE / GPU / CPU 自动路由，模型加密，Instruments profiling 支持）

### 1.5 并发：Swift Concurrency + Actor

**选择：** async/await 作为第一并发原语，重资源隔离用 `actor`（数据库 actor、导入 actor、ML pipeline actor），批处理用 `TaskGroup`。

**Swift 6 严格并发模式开启。** 所有跨 actor 共享的类型必须 `Sendable`。编译期就排除掉一整类数据竞争 bug。

**不用 GCD 裸写**（`DispatchQueue.global().async`）。不用 `OperationQueue` 作为主力（但在桥接老 API 如 `ImageIO` 异步回调时可以用）。

### 1.6 依赖管理：Swift Package Manager 单一入口

**选择：** Xcode project + SPM 管理外部依赖，不用 CocoaPods/Carthage。

**依赖白名单（初步）：**
- GRDB.swift（存储）
- swift-log（日志抽象，后期对接 OSLog）
- swift-collections（有序集合、优先级队列）
- swift-algorithms（批处理算法工具）

**拒绝加的**：任何 Alamofire 级重依赖（URLSession 够用）、任何 JSON 库（Codable 够用）、任何 Promise 库（async/await 替代）、任何 RxSwift/Combine-heavy 库（用原生 Combine/AsyncSequence）。

依赖越少，bundle size 越小，攻击面越小，维护债越少。

---

## 2. 架构设计

### 2.1 分层

```
┌─────────────────────────────────────────────────────────────────┐
│                         App Shell                                │
│        (SwiftUI Scene / Window / Menu / KeyCommand)              │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Feature Modules                             │
│   ┌──────────┐  ┌─────────┐  ┌─────────┐  ┌──────────────┐     │
│   │ Library  │  │  Cull   │  │ Polish  │  │    Create    │     │
│   │          │  │         │  │         │  │              │     │
│   │ SwiftUI+ │  │ SwiftUI+│  │ MetalKit│  │ SwiftUI +    │     │
│   │ AppKit   │  │ AppKit  │  │ Canvas  │  │ PDFKit       │     │
│   └──────────┘  └─────────┘  └─────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Service Layer (actors)                      │
│   ┌────────────────┐ ┌────────────────┐ ┌───────────────────┐   │
│   │ ImportService  │ │ AnalysisService│ │  EditService      │   │
│   │ (file watch,   │ │ (ML pipeline,  │ │  (non-destructive │   │
│   │  ingest actor) │ │  analysis actor)│ │   edit graph)    │   │
│   └────────────────┘ └────────────────┘ └───────────────────┘   │
│   ┌────────────────┐ ┌────────────────┐ ┌───────────────────┐   │
│   │ ExportService  │ │ SpeciesService │ │  ProjectService   │   │
│   │ (render, file  │ │ (Core ML infer,│ │  (session/project │   │
│   │  output)       │ │  local cache)  │ │   lifecycle)      │   │
│   └────────────────┘ └────────────────┘ └───────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Core Domain (pure Swift, UI 无关)           │
│   ┌────────────────┐ ┌────────────────┐ ┌───────────────────┐   │
│   │ Models         │ │ Repositories   │ │  Image Pipeline   │   │
│   │ (Photo, Session│ │ (GRDB records, │ │ (RAW decode,      │   │
│   │  Edit, Species)│ │  queries)      │ │  thumb gen)       │   │
│   └────────────────┘ └────────────────┘ └───────────────────┘   │
│   ┌────────────────┐ ┌────────────────┐                         │
│   │ ML Pipeline    │ │ File System    │                         │
│   │ (Vision/CoreML │ │ (bookmarks,    │                         │
│   │  wrappers)     │ │  watch, paths) │                         │
│   └────────────────┘ └────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│               Platform (macOS system APIs)                       │
│   FileSystemEvents · Spotlight · QuickLook · SharingService     │
│   KeyChain · NSSharingService · NSDocumentController             │
└─────────────────────────────────────────────────────────────────┘
```

**关键规则：**
- Core Domain 零 UI 依赖，零 SwiftUI import。可以被 CLI 工具、单元测试、未来可能的 iPadOS 版本复用。
- Service 层用 actor 隔离有状态的后台工作。
- Feature 模块只依赖 Service 接口（protocol），不直接依赖具体实现——方便单元测试和预览数据替换。

### 2.2 SwiftPM 模块划分

项目分成多个 Swift Package：

```
BirderStudio.xcworkspace
├── App                          (Xcode target, thin shell)
├── Packages/
│   ├── BirderCore               (Core Domain 层)
│   │   ├── Models
│   │   ├── Repositories
│   │   ├── ImagePipeline
│   │   └── MLPipeline
│   ├── BirderServices           (Service 层)
│   ├── BirderUI                 (共享设计系统、UI 组件)
│   │   ├── DesignSystem
│   │   ├── Components
│   │   └── Assets
│   ├── BirderCull               (Cull feature module)
│   ├── BirderPolish             (Polish feature module)
│   │   └── EditorCanvas         (MetalKit-based)
│   ├── BirderCreate             (Create feature module)
│   └── BirderLibrary            (Library/Project feature module)
└── Tests/
    └── (每个包配对的测试 package)
```

**为什么这样切：**
- 模块间强边界，不会出现"UI 调 SQLite"的意大利面条代码
- 单个模块可以独立构建/测试，开发周期短（编译 1 个 feature 模块 2 秒，整个工程 20 秒）
- 未来做 iPad 或 Apple Vision Pro 版本时，Core + Services 可以直接复用

### 2.3 数据流方向

**单向数据流（MVVM + Repository）：**

```
User Action → Feature ViewModel → Service → Repository → Database
                                                 ↓
           SwiftUI View ← @Published state ← ValueObservation (GRDB)
```

- GRDB 的 `ValueObservation` 把数据库变化推给 ViewModel
- ViewModel 把状态以 `@Published` 暴露给 View
- View 响应状态变化重绘
- User Action 走 Service → 数据库变更 → 观察者触发 → View 更新

这避免了"View 里直接调数据库"的耦合，也让数据流可预测、可调试、可测试。

---

## 3. 数据模型

### 3.1 核心表结构（SQLite via GRDB）

```sql
-- 核心资产表：每张照片一行
CREATE TABLE photos (
    id              TEXT PRIMARY KEY,         -- UUID
    session_id      TEXT NOT NULL,            -- 所属 session
    file_bookmark   BLOB NOT NULL,            -- macOS security-scoped bookmark (reference-not-copy)
    file_url_cached TEXT NOT NULL,            -- 便于查询显示的路径（可能过时）
    checksum        TEXT NOT NULL,            -- SHA-256 of first 1MB + size + mtime，快速查重
    file_size       INTEGER NOT NULL,
    file_type       TEXT NOT NULL,            -- "CR3", "NEF", "JPEG", etc.
    
    -- EXIF essentials (extracted once on import, cached)
    captured_at     INTEGER NOT NULL,         -- unix epoch seconds
    camera_make     TEXT,
    camera_model    TEXT,
    lens_model      TEXT,
    focal_length    REAL,
    iso             INTEGER,
    shutter_denom   INTEGER,                  -- 1/1600 stored as 1600
    aperture        REAL,
    gps_lat         REAL,
    gps_lon         REAL,
    image_width     INTEGER NOT NULL,
    image_height    INTEGER NOT NULL,
    
    -- 处理状态
    status          INTEGER NOT NULL DEFAULT 0,  -- enum: imported/analyzing/analyzed/failed
    imported_at     INTEGER NOT NULL,
    analyzed_at     INTEGER,
    
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_photos_session ON photos(session_id, captured_at);
CREATE INDEX idx_photos_checksum ON photos(checksum);

-- Session / outing：每次拍摄
CREATE TABLE sessions (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,            -- "2026-03-15 Bolsa Chica" 自动生成可改
    location_name   TEXT,
    location_lat    REAL,
    location_lon    REAL,
    date_start      INTEGER NOT NULL,
    date_end        INTEGER NOT NULL,
    created_at      INTEGER NOT NULL,
    color_hex       TEXT,                      -- 用户给 session 标颜色
    icon_name       TEXT                       -- 可选图标
);

-- ML 分析结果：每张照片一行
CREATE TABLE photo_analyses (
    photo_id            TEXT PRIMARY KEY,
    
    -- 质量评分（0-1 归一化）
    quality_overall     REAL NOT NULL,
    quality_sharpness   REAL NOT NULL,
    quality_exposure    REAL NOT NULL,
    quality_eye_sharp   REAL,                 -- 若检测到鸟眼
    quality_composition REAL,
    quality_percentile  REAL NOT NULL,        -- 在当前 session 内的百分位
    
    -- 特征指纹（用于去重）
    feature_print       BLOB NOT NULL,        -- VNFeaturePrintObservation 序列化
    
    -- 场景分组
    scene_id            TEXT,                 -- 所属 burst/scene
    is_scene_best       INTEGER DEFAULT 0,    -- 是否场景最佳
    
    analyzed_version    INTEGER NOT NULL,     -- 分析 pipeline 版本号（方便未来重分析）
    
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
);

-- 鸟类边界框（一张照片可能有多只鸟）
CREATE TABLE bird_detections (
    id              TEXT PRIMARY KEY,
    photo_id        TEXT NOT NULL,
    bbox_x          REAL NOT NULL,            -- 归一化 [0,1]
    bbox_y          REAL NOT NULL,
    bbox_w          REAL NOT NULL,
    bbox_h          REAL NOT NULL,
    confidence      REAL NOT NULL,
    
    -- 物种识别结果（可能未识别）
    species_id      TEXT,
    species_confidence REAL,
    species_source  TEXT,                     -- "ml" / "user" / "unknown"
    
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE,
    FOREIGN KEY (species_id) REFERENCES species(id)
);

-- 物种分类表（离线自带全球 10k 种 eBird taxonomy）
CREATE TABLE species (
    id              TEXT PRIMARY KEY,          -- eBird 分类 ID
    common_name_en  TEXT NOT NULL,
    common_name_zh  TEXT,
    scientific_name TEXT NOT NULL,
    family          TEXT,
    family_zh       TEXT,
    order_name      TEXT
);

CREATE VIRTUAL TABLE species_fts USING fts5(
    id, common_name_en, common_name_zh, scientific_name,
    content='species', content_rowid='rowid'
);  -- 用 FTS5 做物种名模糊搜索

-- 用户评级（accept/reject/star/flag）
CREATE TABLE photo_ratings (
    photo_id    TEXT PRIMARY KEY,
    decision    INTEGER,                      -- 1=accept, 0=unrated, -1=reject
    star        INTEGER,                      -- 0-5
    color_label INTEGER,                      -- 0-7 (类似 Lightroom 的 color label)
    note        TEXT,
    rated_at    INTEGER NOT NULL,
    
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
);

-- 非破坏性编辑图（每个照片 0 到多个 edit snapshot）
CREATE TABLE edits (
    id              TEXT PRIMARY KEY,
    photo_id        TEXT NOT NULL,
    edit_json       TEXT NOT NULL,            -- 序列化的 EditGraph
    name            TEXT,                     -- "Published Version", "Darker Mood" 等
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL,
    is_current      INTEGER DEFAULT 0,        -- 当前应用的版本
    
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
);

-- 项目（跨 session 的工作集，如"2026 春迁精选"）
CREATE TABLE projects (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    created_at  INTEGER NOT NULL
);

CREATE TABLE project_photos (
    project_id  TEXT NOT NULL,
    photo_id    TEXT NOT NULL,
    order_idx   INTEGER NOT NULL,
    PRIMARY KEY (project_id, photo_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
);
```

### 3.2 文件系统布局

```
~/Library/Application Support/BirderStudio/
├── library.sqlite              (主数据库 via GRDB)
├── library.sqlite-wal          (WAL mode for concurrency)
├── models/                     (Core ML 模型动态下载，不 bundle)
│   ├── bird_detect_v1.mlmodelc
│   └── quality_nima_v1.mlmodelc
├── thumbnails/                 (缩略图缓存，按 UUID 前两位分片)
│   ├── ab/abc123...uuid.heic   (256px for grid)
│   └── ...
├── previews/                   (预览图缓存，1200px)
│   └── ab/abc123...uuid.heic
├── exports/                    (用户导出的最终图)
│   └── {session_name}/...
└── species_taxonomy.sqlite     (eBird 分类只读数据库)
```

**关键设计决策：**

1. **Reference-not-copy：** RAW 文件留在用户原位置（通常外置 SSD 或相机导入目录）。我们存 `file_bookmark`（macOS security-scoped bookmark）确保文件移动后还能找到。
2. **Thumbnail 分片目录：** 避免单目录百万文件。
3. **HEIC 格式缩略图：** 比 JPEG 小 50%，质量同等，Apple 原生硬件加速编解码。
4. **Models 按需下载：** 首次启动时从 CDN 下载 40MB 模型包，bundle 不自带，首次启动 bundle < 100MB。
5. **Species taxonomy 是独立只读 SQLite：** 方便更新（eBird 每年发新版分类），跟 library.sqlite 分离。

### 3.3 非破坏性编辑图

编辑不改原文件、不烘焙到像素。`edits.edit_json` 是一个 `EditGraph`：

```swift
struct EditGraph: Codable, Sendable {
    let version: Int = 1
    let crop: CropParams?
    let exposure: ExposureParams?
    let whiteBalance: WhiteBalanceParams?
    let sharpen: SharpenParams?
    let denoise: DenoiseParams?
    let vibrance: VibranceParams?
    let vignette: VignetteParams?
    let eyeBrighten: EyeBrightenParams?
    let backgroundBlur: BackgroundBlurParams?
    let watermark: WatermarkParams?
    let preset: PresetApplication?       // 记录"应用了 Bird Portrait" + 任何手动覆盖
    let overlays: [OverlayLayer]         // 物种标签、EXIF、箭头等
}
```

每个参数是一个小的 Codable struct。整个图用 JSON 序列化存进 `edits.edit_json`。

**为什么 JSON 而不是二进制：** 调试时能直接看、diff 友好、未来迁移版本容易。性能不是瓶颈（一张照片的 EditGraph 通常 < 1KB）。

**渲染时：** Pipeline 按固定顺序应用：`decode → crop → exposure → WB → sharpen → ...`。每个步骤是一个 `CIFilter` 或自定义 Metal pass，串成 `CIImage` 链。

---

## 4. 图像与性能架构

### 4.1 缩略图管线

**目标：** 导入 2000 张 RAW → 60 秒内全部可见缩略图；用户滚动网格时 60fps 无掉帧。

**策略：**

```
Import Phase (backgrounded, actor-isolated):
    for each new file (parallelized, TaskGroup, CPU 核数为上限):
        1. EXIF 提取        (~5ms,  ImageIO metadata API)
        2. 生成 256px thumb  (~30ms, ImageIO + vImage resize)
        3. 生成 1200px preview (~80ms, same)
        4. 计算 checksum    (~10ms, SHA-256 first 1MB)
        5. 写入数据库 + 文件
    → 单张端到端 ~150ms, 8 核并行 ~20 photos/sec → 2000 张 100 秒
    → 优化：前 50 张 priority boost，让用户立即看到第一页
```

**优化：**
- 用 `CGImageSource` + `kCGImageSourceCreateThumbnailFromImageAlways` 让 ImageIO 直接生成缩略图（比解码全图再 resize 快 3 倍）
- 超大 RAW（>30MP）用相机内嵌的 JPEG preview 当缩略源（ImageIO 有 `kCGImageSourceCreateThumbnailWithTransform` 选项）
- Thumbnail 保存用 HEIC，libheif 硬件加速编码 ~10ms

### 4.2 Cull 视图的 60fps 保证

**问题：** 用户连续按左右箭头切换照片，每次切换要加载 1200px preview、EXIF、ML 分析结果、边界框叠加。传统实现卡顿。

**方案：预加载 + 双缓冲**

```swift
actor CullNavigator {
    private var photos: [PhotoID]
    private var currentIndex: Int
    
    // 缓存当前 ± 5 张的预览图
    private var preloadedPreviews: [PhotoID: PreviewImage] = [:]
    
    func navigate(direction: NavDirection) async -> PhotoDisplay {
        currentIndex += direction.offset
        
        // 立即返回已缓存的（< 16ms）
        let current = await displayFor(currentIndex)
        
        // 后台预加载下一批
        Task.detached(priority: .userInitiated) {
            await preloadAhead(of: currentIndex, count: 5)
        }
        
        return current
    }
}
```

**性能合同：**
- 按键 → 主 canvas 更新 < 16ms（preview 已在内存）
- 如果缓存未命中（用户跳得很远），先显示模糊缩略图（256px，已缓存），1200px 加载完再替换
- EXIF / ML 结果在独立 task 加载，不阻塞主图显示

### 4.3 编辑器画布（Polish 阶段的核心技术挑战）

**目标：** 拖动曝光滑块时，1200px 预览实时响应 60fps。

**方案：** MetalKit + CIImage 混合

```
EditorCanvasView (NSViewRepresentable wrapping MTKView)
    └── 持有一个 CIContext（metal backing）
    └── 持有当前 CIImage（解码后的原图，缓存）
    └── 持有 EditGraph 当前值
    
当用户拖滑块：
    1. 更新 EditGraph.exposure.value（主线程，trivial）
    2. 标记 needsRedraw = true
    3. MTKView 下一个 displayLink tick 调 draw(in:)
    4. draw 时：
        a. 从缓存取 sourceImage (CIImage)
        b. 通过 EditPipeline.apply(graph:) 得到 outputCIImage
        c. ciContext.render(outputCIImage, to: drawable.texture, ...)
        d. commandBuffer.present(drawable)
        
    → 每帧 < 16ms，GPU 负责全部重绘，CPU 几乎不参与
```

**关键优化：**
- 预览分辨率限制在 1200px（实际渲染尺寸），导出时才用原始尺寸
- CIImage 是惰性的——修改滑块不重新解码 RAW，只是改变 filter 参数
- 对于高开销滤镜（羽毛锐化、降噪），拖动时禁用，松手时应用（"旋钮反馈延迟"模式）

### 4.4 性能预算表

| 操作 | 目标 | 来源 |
|---|---|---|
| 冷启动到可交互 | < 500ms | 用户信任的基准，Raycast 水准 |
| Library 首屏 100 缩略图 | < 200ms 全部显示 | 滚动时 60fps |
| RAW 导入单张（不含分析） | < 150ms | 2000 张 8 核 20 秒可见 |
| ML 分析单张（bbox + quality + feature print） | < 100ms | 2000 张 20 分钟全部分析完 |
| 本地物种识别单张（Core ML，Apple Silicon） | < 50ms | 2000 张 2-3 分钟全部识别完 |
| 编辑器滑块拖动 | 60fps 持续 | 不可协商 |
| 导出单张 JPEG | < 500ms | 批量导出 100 张 < 50 秒 |
| Cmd+K 全局搜索响应 | < 50ms | 感觉像 Linear |
| Bundle size（不含按需下载的模型） | < 100MB | 初次下载 |
| Bundle size（全部模型下载完） | < 150MB | 正常运行状态 |

**CI 里的性能回归测试：** 每次 commit 跑一个基准测试套件，跑 50 张固定 RAW → 记录各阶段耗时 → 超过 15% 退化就 fail。这一项在 Project Phase 1 就建立。

---

## 5. ML 架构

### 5.1 管线总览（全本地，零云端）

```
Import
  └─→ Analysis Pipeline (backgrounded per-photo, actor-isolated)
         │
         ├─→ 1. Bird Bounding Box
         │    └─ Apple Vision saliency（初筛） + YOLO-v8 nano Core ML (~8MB)
         │       来源：开源 YOLO-v8 在 NABirds/iNaturalist 上 fine-tune 的权重
         │       输出：0-N 个 bbox，置信度
         │
         ├─→ 2. Per-bird crop
         │    └─ 从 RAW 预览切出每只鸟的 ROI 和周边环境
         │
         ├─→ 3. Quality Scoring (并行各子项)
         │    ├─ NIMA 美学评分 (Core ML MobileNetV2, ~14MB)
         │    ├─ 清晰度 (Laplacian variance on bird ROI)
         │    ├─ 眼部清晰度 (crop 鸟头 Laplacian)
         │    ├─ 曝光 (CIAreaHistogram)
         │    └─ 构图 (saliency 中心 → rule-of-thirds 距离)
         │    → 加权合成 quality_overall，再按 session 内百分位归一化
         │
         ├─→ 4. Feature Print (去重用)
         │    └─ VNGenerateImageFeaturePrintRequest (系统 API, 0MB)
         │       输出：128 维浮点向量
         │
         └─→ 5. Species ID (本地 Core ML，与上述并行)
              └─ EfficientNet-B2 或 ViT-S，iNaturalist 鸟类子集预训练 → Core ML (~18MB)
                 对每只 bbox 切图做分类，top-3 + 置信度
                 Apple Neural Engine 单张 10-30ms
                 本地 cache：checksum + bbox_hash → species_id（避免重复推理）
```

**全流水线预算（2000 张 session，M-series Mac，并行 8 核 + NE）：**

| 阶段 | 单张耗时 | 2000 张总耗时 |
|---|---|---|
| Bbox 检测 | 20-40ms | 40-80s |
| 质量评分 | 30-50ms | 60-100s |
| Feature print | 10-20ms | 20-40s |
| 物种识别（每只鸟 20ms × 1.5 均鸟数） | 20-30ms | 40-60s |
| **整体（并行）** | — | **~3 分钟** |

对比云端方案：单张 1-2s × 2000 = 33-67 分钟，完全不可接受。本地是唯一路径。

### 5.2 场景分组算法

**输入：** 一个 session 内所有照片的 feature_print + captured_at
**输出：** 每张照片的 scene_id 和 is_scene_best 标记

```swift
func groupScenes(photos: [AnalyzedPhoto]) -> [Scene] {
    // Stage 1: 时间相邻（2 秒内）预分组
    let timeClusters = clusterByTime(photos, gap: 2.0)
    
    // Stage 2: 每个时间簇内用 feature print 距离做层次聚类
    var scenes: [Scene] = []
    for cluster in timeClusters {
        let distances = computeFeaturePrintDistances(cluster)
        let subScenes = hierarchicalCluster(cluster, distances: distances, threshold: 8.0)
        scenes.append(contentsOf: subScenes)
    }
    
    // Stage 3: 每个 scene 内选最佳
    for i in 0..<scenes.count {
        scenes[i].bestPhotoID = scenes[i].photos.max(by: { $0.quality < $1.quality })?.id
    }
    
    return scenes
}
```

**阈值调优**：阈值 8.0 是基于 VNFeaturePrint 经验值（鸟类摄影场景下），但必须可配置——用户可以在偏好设置里调"场景分组松紧度"。

### 5.3 物种识别的"足够好"定义

引用 `feedback_no_ai_accuracy_race.md` + `project_local_first_ml.md`：不追准确率竞赛、不走云端、不自训模型。具体怎么做：

```
Strategy:
    1. 每个 bbox 的裁剪图过本地 Core ML 分类器（EfficientNet 或 ViT）
    2. 输出 top-3 + softmax 置信度
    3. 轻量后验修正（可选）：用 GPS + 月份做粗粒度地理过滤
       （eBird 分布图离线包，筛掉地理上不可能出现的物种）
       注意：不是 Bayesian 后验全流水，只是把"北美看到亚洲特有种"这种明显错误压下来
    4. 本地缓存：checksum + bbox_hash → species_id，避免重复推理
    5. UI 表现：
       - high confidence (>0.85): 直接显示物种名
       - medium (0.5-0.85): 显示物种名 + 小 "?" 图标，点击看 top-3
       - low (<0.5): 显示 "Possibly {species}"，用户点击才定
       - 无 bbox 或分类器 abstain: 显示 "Unidentified"，不自动分类
    6. 用户修正 = 写入 bird_detections.species_source = "user"，永久覆盖 ML 结果

NOT doing:
    - 云端 API 调用（Claude Vision / OpenAI Vision / Gemini）——速度毁体验
    - 自训模型、数据飞轮、Active Learning
    - 多模型投票集成
    - 复杂的分层管线（Merlin 那套工程我们不跟）
```

**接受的局限：** 常见鸟种 80-90% 准确率 vs Merlin 的 95%+。这是为"2000 张 3 分钟出结果"付出的代价，并且**用户修正本身就是产品的一部分**——Cull 模式下手动修改物种名只需一次按键。

**地理覆盖（关键开放决策，见 §10 D4）：**
- NABirds 预训练权重：北美 555 种，欧洲鸟种部分覆盖，东亚几乎不覆盖
- iNaturalist 2021/2024 竞赛全球鸟类子集：约 900-1000 种，覆盖更广但每种样本少、长尾准确率差
- 中国/东亚本地观鸟者（包括 Bruce 自己）需要的是第三方区域训练的模型（台湾、日本、中国大陆的观鸟社区或学术项目发布的开源权重），v1 必须给出答案而不是"先发北美版再说"

---

## 6. 设计系统与 10x 美学基础

根据 `feedback_10x_craft_bar.md`，10x 交互和美感是底线。这里不是形容词，是**具体可验证的实现**。

### 6.1 设计 token 系统

所有视觉参数收敛到一个 Swift module（`BirderUI/DesignSystem`），**不允许**在业务代码里写硬编码颜色、字号、间距。

```swift
public enum Spacing {
    public static let hair:   CGFloat = 1
    public static let xs:     CGFloat = 4
    public static let sm:     CGFloat = 8
    public static let md:     CGFloat = 12
    public static let lg:     CGFloat = 16
    public static let xl:     CGFloat = 24
    public static let xxl:    CGFloat = 40
    public static let xxxl:   CGFloat = 64
}

public enum Typography {
    public static let display  = Font.custom("InterDisplay-Semibold", size: 28)
    public static let title    = Font.custom("InterDisplay-Semibold", size: 20)
    public static let body     = Font.custom("Inter-Regular", size: 14)
    public static let caption  = Font.custom("Inter-Regular", size: 12)
    public static let mono     = Font.custom("JetBrainsMono-Regular", size: 12)
    public static let species  = Font.custom("NewYorkMedium-Medium", size: 16)   // 物种名专用：衬线，博物学家感
}

public enum ColorPalette {
    // Dark mode 真正的暗房色：非纯黑（#000 太硬），深蓝灰
    public static let canvasBackground  = Color(hex: 0x0A0C10)
    public static let surfaceElevated   = Color(hex: 0x15181E)
    public static let border            = Color(hex: 0x23272E).opacity(0.5)
    public static let textPrimary       = Color(hex: 0xE8EBEF)
    public static let textSecondary     = Color(hex: 0x8A9099)
    public static let accent            = Color(hex: 0xF5A623)   // 琥珀色，温暖而非工业蓝
    public static let accentMuted       = Color(hex: 0xA67A1F)
    // Semantic colors
    public static let accept            = Color(hex: 0x4ADE80)
    public static let reject            = Color(hex: 0xFB7185)
    public static let warning           = Color(hex: 0xFBBF24)
}
```

**为什么选 Inter 不是 SF Pro：** SF Pro 是系统字体，每个 Mac app 都用。为了让 Birder Studio 在截屏和 icon 上立刻被识别，我们用 Inter（开源、优秀数字表现、可商用）+ New York（Apple 系统自带的衬线，鸟类命名天然适合衬线）。JetBrains Mono 用于 EXIF 数值显示。

**不用 SF Pro 的更重要原因：** 它是好字体，但它不是**独特**的字体。10x 标准要求每个选择都是经过考虑的，不是 Xcode 默认的。

### 6.2 动效系统

所有动画用统一的 `Motion` 枚举定义：

```swift
public enum Motion {
    // Timing curves（Apple HIG 没给这些精确值，我们自定义）
    public static let snap    = Animation.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.18)
    public static let smooth  = Animation.timingCurve(0.4, 0.0, 0.2, 1.0,  duration: 0.3)
    public static let gentle  = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.5)
    public static let bounce  = Animation.spring(response: 0.4, dampingFraction: 0.7)
    
    // Semantic uses
    public static let keyboardNav = snap           // 键盘切图要感觉"snap"
    public static let sidebarToggle = smooth
    public static let photoEnter = gentle
    public static let cardAccept = bounce          // accept/reject 给一点弹性反馈
}
```

**规则：**
- 不允许用 `Animation.default`（那是 0.35s ease-in-out，世界上最平庸的动画）
- 超过 300ms 的动画必须可跳过（用户按 Esc 或直接操作会打断）
- 键盘导航的响应动画必须 ≤ 200ms（不然感觉软件跟不上）

### 6.3 图标系统

**决策：** 自建 icon set（约 60 个图标），存为 SF Symbols 格式（`.svg` + variable axis），而不是直接用 SF Symbols 系统图标。

**为什么：** SF Symbols 是好的，但每个图标都有 iOS 的视觉遗产，并且所有 app 长得一样。我们的 UI 要有自己的识别度。图标都是"鸟类自然史博物馆"风格（细线条、略带手绘感、博物学家插画的抽象化），不是 Material Design 或 HIG 默认。

**v1 自建的核心图标：**
- App 图标（见 6.6）
- Cull / Polish / Create 模式切换（三个具象但抽象化的图标）
- 鸟类相关操作（鸟眼提亮、智能裁切、羽毛锐化——每个都有一个对应的标志性图标）
- Session / Project / Life List 分类图标

委托专业 Mac icon 设计师做，预算 $2000-5000，不是可省的。

### 6.4 窗口和布局

**主窗口 baseline：** 1280 × 800（紧凑模式），推荐 1600 × 1000。

**区域划分：**
```
┌──────────────────────────────────────────────────────────────┐
│  ┌─ Sidebar (collapsible) ─┐  ┌── Main Canvas ──────────┐   │
│  │                         │  │                         │   │
│  │  Sessions               │  │  Photo / Editor /       │   │
│  │  Projects               │  │  Template               │   │
│  │  Species                │  │                         │   │
│  │  Life List              │  │                         │   │
│  │                         │  │                         │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
│                                                              │
│  ┌─ Film Strip (bottom) ──────────────────────────────────┐  │
│  │  □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ │  │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
Top-level mode switch (Cmd+1/2/3): Cull | Polish | Create
```

**键盘第一：**
- `Cmd+1/2/3` 切换 Cull/Polish/Create
- 左右箭头导航照片；上下切换 scene
- `A` accept, `R` reject, `S` star, 数字键 1-5 打星级
- `Space` 放大到全屏
- `Cmd+K` 全局搜索（物种、日期、地点、文字）
- `Cmd+E` 快速导出
- `?` 显示当前上下文所有快捷键

### 6.5 Empty State 和 Loading State 清单

**禁止出现的：**
- 原生 spinner (`ProgressView()`)，除非是极短暂的 < 200ms loading
- "No items" 字样
- 系统默认的错误 alert

**必须设计的：**
- 首次启动的欢迎态（插画 + 引导拖入第一个 session）
- 空 Library 态（引导导入）
- 空 Scene / 空 Project 态
- 分析进行中的进度展示（动画+阶段说明："正在识别鸟类... 237/2000"）
- 离线态（云端物种 ID 失败时的友好提示）
- 权限拒绝态（用户没给 Full Disk Access 时）
- 网络错误态（可重试）

每一个都有独立插画（委托插画师做）+ 行动号召文案。

### 6.6 App 图标

委托专业 Mac icon designer。参考：Things 3、Ulysses、Mela。要求：
- 单色可识别（dock 微缩下能分辨）
- 鸟类元素但非俗气卡通
- 暗色模式和亮色模式下都出色
- iOS 风格现代感但有博物学家细腻感

不是 $200 在 Fiverr 能解决的事，预算 $3000-8000。

---

## 7. 构建顺序（De-risk First, Not Feature First）

PRD 的 5 阶段（基础→Cull→Polish→Create→打磨）是按**功能**切的，这是最危险的顺序——它把所有技术风险推到后面。**我们按风险切。**

### Phase 0: 技术验证与脚手架（Week 1-2）

**目标：** 把最高风险的 3 个技术决策实际跑通。如果这阶段失败，我们调整技术栈。

- [ ] Swift Package Manager 多模块工程骨架（App + BirderCore + BirderUI）
- [ ] GRDB 集成 + Schema v1 + migration 机制
- [ ] **技术验证 A：** 导入 2000 张真实 RAW 照片，测量 thumbnail 生成耗时。目标 < 100 秒，否则优化或换方案。
- [ ] **技术验证 B：** MetalKit + CIImage 实时预览。拖动一个 `exposure` 滑块，测量 60fps 能否稳定。
- [ ] **技术验证 C：** Vision Framework feature print 500 张照片距离矩阵计算耗时。目标 < 30 秒。
- [ ] CI 建立：测试 + SwiftLint + 基准测试回归
- [ ] 设计系统基础：typography / color / spacing / motion tokens，第一版 sidebar 和 navigation shell

**Go/No-Go 标准：** 三个验证项目全过 → 进入 Phase 1。任何一个过不了，停下来决定是优化还是换技术方案。

**为什么放在最前：** ProjectKestrel 的教训是"先写功能再发现性能过不了关"，我们要反过来。

### Phase 1: Library + Import（Week 3-5）

**目标：** 用户能把 RAW 倒进来，看到一个美的、快的照片网格。这是整个 app 的"入口体验"。

- [ ] Import Service + actor（支持拖拽文件夹、文件、多 session 批量）
- [ ] 文件浏览器（sidebar：Sessions 列表）
- [ ] `PhotoGridView`（AppKit NSCollectionView wrapped），真正做到滚动 60fps
- [ ] 详情视图（大图 + EXIF inspector）
- [ ] Reference-not-copy 实现 + bookmark 失效处理 UI
- [ ] 缩略图后台生成队列
- [ ] Cmd+K 第一版（搜 session 名、文件名）

**Deliverable：** 能 demo 给 3 个真实鸟友用，"把我的 SD 卡拖进来看照片"比 Apple Photos 爽。

### Phase 2: Cull（Week 6-9）

**目标：** Cull 模式从"能用"到"10x 好用"。这是 app 的核心价值。

- [ ] Analysis Service + ML pipeline（Vision feature print + quality scoring + bbox detection）
- [ ] Scene 分组算法 + UI 呈现
- [ ] Cull 视图（键盘驱动，accept/reject/star 都即时响应）
- [ ] 批量操作（整 scene accept/reject）
- [ ] 对比视图（A/B 两张全屏对比）
- [ ] Session 统计条（"2341 张中 47 张被保留"）
- [ ] 本地 Core ML 物种识别 service：模型按需下载（首次启动）+ 推理缓存 + Neural Engine 路由
- [ ] 区域模型包策略：北美（NABirds）默认，欧洲/亚洲额外下载包（§10 D4 决策后实现）
- [ ] 物种名的本地离线 taxonomy（FTS5 搜索，中英双语）
- [ ] eBird 地理分布离线包集成（做物种候选的粗粒度过滤）

**Deliverable：** v0.5 发给 5-10 个真实鸟友用。我们的成功标准来自 PRD 迁移建议（写入 memory）：第二次 session 还回来用吗？从导入到精选多快？AI 修正次数减少吗？

### Phase 3: Polish（Week 10-14）

**目标：** 编辑器 60fps，一键预设让人惊艳。

- [ ] EditorCanvas（MetalKit + Core Image pipeline）
- [ ] EditGraph 数据模型 + 非破坏性编辑存储
- [ ] 基础调整：裁切、曝光、白平衡、锐化、饱和度、降噪
- [ ] Auto-crop（智能裁切，基于 bbox + rule-of-thirds）
- [ ] 一键预设 × 5（Bird Portrait, Field Guide, Drama, Clean & Bright, Social Ready）
- [ ] 批量应用：一张 edit → 整个 scene
- [ ] 水印系统（文字 + 图片 + 智能避让）
- [ ] 标注叠加（物种标签、EXIF、箭头）
- [ ] 导出 pipeline（平台预设、批量）

**Deliverable：** v0.8 发给种子用户。他们能完成完整工作流："导入 → 筛选 → 精修 → 分享到社交媒体"。

### Phase 4: Create（Week 15-20）

**目标：** 从照片到产品。这部分功能范围大，分三个交付点。

**4a：社交拼图 + 数字图鉴（Week 15-17）**
- [ ] Social Collage 构建器（2x2, 3x3, 对比网格）
- [ ] Personal Field Guide 自动排版引擎（物种页 template）
- [ ] 印刷级 PDF 导出（CMYK、出血位、300 DPI）

**4b：印刷品模板（Week 18-19）**
- [ ] 明信片、贺卡、月历、艺术版画的模板引擎
- [ ] Poster（Life List 网格、大年总结）

**4c：AI 生成（Week 20，status 待定）**
- [ ] Photo-to-illustration / Text-to-bird-art —— **本地优先原则下重新评估**：
  - 云端 API（快速接入，但违反 local-first 原则、需要网络、有成本）
  - 本地 Stable Diffusion / CoreML Stable Diffusion（bundle +2GB，启动慢，模型选型维护重）
  - **倾向：v1 不做 AI 生成**，留到 v1.5 或更晚。专注把 Cull/Polish/Create 的非 AI 部分做到 10x。
- [ ] 穿戴品和物品的模板先只做预览 mockup，POD 集成推迟

**决策：** Wearables（T-shirt / mug / hat）**不在 v1**。理由是它们真正使用的用户比例可能 < 5%，但开发 POD 深度集成（Printful/Redbubble API）成本很高。先在 Polish 或 Create 的导出设置里提供"高分辨率印刷品"的通用导出，让用户自己上传到第三方服务。等数据证明有足够用户想要我们再做深度集成。

### Phase 5: Polish & Ship（Week 21-24）

- [ ] 性能优化：用 Instruments 跑 10 次典型 workflow，消灭掉耗时 top 10
- [ ] 动画和微交互：每个 transition 手动调优
- [ ] 无障碍审计：VoiceOver、Dynamic Type、键盘全覆盖
- [ ] 本地化：中文（简体/繁体）+ 英文物种名（基于 eBird taxonomy）
- [ ] 错误处理 + 离线处理的每个边缘情况
- [ ] 发布材料：截图、demo 视频、Landing page（分发渠道本身是商业决策，推迟到功能稳定后再谈）
- [ ] Beta 测试流程走完

### 整体节奏

| Phase | 周 | 产出 | 关键里程碑 |
|---|---|---|---|
| 0 | 1-2 | 脚手架 + 技术验证 | 性能基线建立 |
| 1 | 3-5 | Library 和 Import | 鸟友能看到他们的照片 |
| 2 | 6-9 | Cull 完整 | **v0.5 发 10 个种子用户** |
| 3 | 10-14 | Polish 完整 | **v0.8 发 20 个用户** |
| 4 | 15-20 | Create 分三批 | v0.9 分阶段发 |
| 5 | 21-24 | 打磨发布 | **v1.0 可发布状态** |

总计 24 周 ≈ 6 个月。**这个节奏假设全职 1-2 个开发者 + 1 个设计合伙（兼职）+ 第三方美术外包**。如果团队配置不同，节奏线性伸缩。

---

## 8. 质量底线（Non-Negotiables）

这些是"10x craft 标准"的具体不协商项。任何 PR 如果破坏这些都必须被 block。

1. **启动时间 < 500ms 到可交互。** 任何为方便加的"初始化"都必须移到后台或 lazy。
2. **60fps 滚动 photo grid。** Instruments 里 main thread 任何 stall > 16ms 都是 P0 bug。
3. **任何操作的反馈 < 100ms。** 超过就需要 skeleton UI、进度提示或乐观更新。
4. **每一个 Animation 有显式的 timing curve。** 禁止用 `Animation.default`。
5. **每一个 empty state / error state 是设计过的。** 不允许出现 "No results." 或原生 Error alert。
6. **每个主要功能有键盘快捷键。** 不能只靠鼠标触达的功能不是"Mac 应用"。
7. **深色模式是真暗房。** `#000` 和 `#1a1a1a` 都不对——要有层次的深色灰，让照片从屏幕里"发光"。
8. **每个功能有 telemetry 但默认不发。** 用户明确同意后才上报匿名使用数据。
9. **Crash-free 率 > 99.5%。** Sentry/osCrashReporter 对接，每个 crash 作为 P1 处理。
10. **内存：10k 照片 library 稳态内存 < 800MB。** 超过说明 leak 或 cache 策略错。
11. **所有 Service 层有单元测试。** 核心 Domain model 100% 分支覆盖。
12. **所有 SQL 查询 < 10ms（10k 规模）。** EXPLAIN QUERY PLAN 检查、必要索引建立。

**治理机制：** CI 跑完这 12 项的自动化检查（能测的），PR 必须全绿才能 merge。

---

## 9. 从 ProjectKestrel 借鉴与避免的具体清单

基于对 `/Users/bruce.y/GitCode/ProjectKestrel` 的深入分析。

### 值得借鉴：

1. **Lazy model loading 模式。** 模型只在实际需要分析时加载。我们用 Core ML，配合 Swift 的 async lazy init。
2. **分析 pipeline 与 UI 解耦。** `BirderCore` 包零 UI 依赖，CLI 工具、未来 iOS 版本都可复用。
3. **Relative path 持久化哲学。** 用 macOS security-scoped bookmarks（更强版本），而不是纯相对路径。
4. **质量归一化为百分位。** 用户看到的 quality score 是"这张照片在本 session 内的百分位"，而非 raw 数值。更直观。
5. **AKAZE + 色彩直方图 fallback 思路可借鉴**（但实现上我们用 VNFeaturePrint 就够了，不需要 OpenCV）。

### 必须避免：

1. **不 bundle 多个 ML 框架。** ProjectKestrel 同时带 PyTorch + TensorFlow + ONNX Runtime（总共 > 1GB）。我们只用 Core ML + Vision（已在系统内，零 bundle 成本）。
2. **不用 Python + pywebview。** 全 Swift，bundle < 150MB。
3. **不把测试图片和 readme 图片放 git。** 它们有 745MB。我们单独仓库管理测试数据。
4. **不用 CSV + JSON-in-string 存结构化数据。** 用 GRDB + 正规化 schema。
5. **写单元测试。** ProjectKestrel 零测试。我们 Core domain 100% 分支，Services 80%+。
6. **不做单线程顺序分析。** 我们 TaskGroup 并行，榨干多核。
7. **不做 1,400 行的 god pipeline。** 按分析 stage 拆 actor，每个 < 300 行。

---

## 10. 开放决策（需要你确认）

这些是功能/技术层面我有倾向但想请你拍板的决策。**商业化相关（定价、分发渠道、收费模式）一律不在 v1 讨论范围**——见 Bruce 的明确指示"商业的部分先不要管，先把功能实现好"。

### D1: macOS 最低支持版本
- **我的倾向：** macOS 15 Sequoia+（2024 发布）。
- **Why：** Swift 6 严格并发、SwiftUI 最新 API、Vision 最新模型支持。牺牲 ~20% 用户（还在老 Mac 上）。
- **可选：** macOS 14（扩大 10-15% 用户，牺牲一些 API）。
- **决策后果：** 影响团队能用什么框架特性和 API。

### D2: Wearables 周边（T 恤/杯子/帽子）是否进 v1 功能范围
- **我的倾向：** 不进 v1，放 v1.5 或 v2。用一个"高分辨率印刷品导出" template 作为替代。
- **Why：** POD（Printful/Redbubble）深度集成开发成本高但真正使用率可能 < 5%。v1 应集中把核心打爆。
- **反方：** 你说要 all-in-one，砍掉这些会不会违背 vision？我的判断：**all-in-one 是愿景，v1 是踏脚石**，v1 有 Cull + Polish + 数字品 Create + 社交拼图 + 图鉴印刷就已经是 all-in-one 的雏形了。T 恤那些可以很快补。

### D3: AI 生成功能（photo-to-illustration, text-to-bird-art）在 v1 的位置
- **我的倾向：** v1 **不做** AI 生成。留到 v1.5 或更晚。
- **Why：** 与"ML 本地优先，零云端"原则冲突。本地 SD 增加 2GB bundle 且维护重；云端 API 违反核心原则。v1 把非 AI 的 Create（拼图、图鉴、印刷品模板）做到 10x，比勉强塞一个 AI 生成按钮更有价值。
- **反方：** 如果你认为 photo-to-illustration 对"从照片到礼物"闭环必要，我们可以设计为 opt-in 云端功能（用户主动点击，明确说明要联网），但这是例外，不是默认管线。

### D4: 物种识别模型的地理覆盖策略（**v1 必须解决，不可延迟**）
- **背景：** Bruce 在上海/崇明观鸟。现有公开模型（NABirds / iNaturalist 子集）对东亚覆盖不足。这是真问题。
- **候选方案：**
  - **A：单一全球模型。** 用 iNaturalist 全球鸟类子集（~1000 种），接受长尾准确率差。Bundle 15-25MB。
  - **B：区域模型包。** 默认北美包（NABirds），欧洲/东亚/南美独立下载包。每个 15-25MB。用户按需下载。
  - **C：两层结构。** 一个全球粗分类器（~500 种科级+常见种）+ 按需的区域细分类器包。
- **我的倾向：B（区域包）。** 透明、可扩展、首次启动下载符合用户预期。区域包可以来自当地观鸟社区开源项目（例如 BirdsOfShanghai、Bird-ID-China 类型的学术/社区权重）。
- **需要你决策：** B 可以接受吗？如果可以，v1 发北美 + 东亚两个包；如果倾向 A，我去找全球最好的开源模型。

### D5: eBird 集成深度
- **我的倾向：** v1 用它的 taxonomy 数据（下载离线包）+ 物种地理分布数据（做识别后验过滤），**不**用它的 API 上传 checklist。
- **Why：** Taxonomy 和分布数据开放免费；API 要 partnership，沟通周期长。用户想上 eBird 我们做"复制为 eBird 格式"的导出即可。
- **未来：** 若有精力 v1.5 做 API 集成。

### D6: 模型分发机制
- **我的倾向：** 首次启动从自建 CDN 按需下载（S3 + CloudFront）。不 bundle 到 App 里（保持首次下载 < 100MB）。
- **Why：** 模型会随时间更新，bundle 内模型意味着每次更新都是 App 整体更新。CDN 分发允许独立版本化。
- **风险：** 用户第一次启动需要网络；需要自己的 CDN 基础设施。
- **备选：** Bundle 最小的默认模型（bbox + quality，约 22MB），物种分类器按需下载。这样首次启动离线也能分析照片，只是没物种名。

---

## 11. 立即要做的事（本周）

如果你批准这个规划，我建议这周开始：

1. **开 Xcode 项目骨架**（半天）——SPM 多模块结构，写出第一个"Hello Birder Studio"窗口
2. **四个技术验证 spike**（4 天）——分别用一天做：
   - RAW 导入 2000 张的缩略图性能测试
   - MetalKit 编辑器 60fps 测试
   - Vision feature print 批量计算测试
   - **Core ML 物种分类器本地推理 benchmark**（拿一个公开的 iNaturalist fine-tuned 模型转 Core ML，测 Apple Silicon 上单张耗时和准确率，验证"本地方案可行"这个核心假设）
3. **调研并选定鸟类物种分类模型**（§10 D4）——列出 3-5 个候选开源权重（NABirds、iNaturalist、HuggingFace、学术项目），评估授权/覆盖/大小/准确率，给出推荐
4. **设置 GitHub repo + CI + SwiftLint**（半天）
5. **联系种子鸟友**——至少 5 个真实用户在 Phase 2 末尾能用上 v0.5

我可以立即开始 1、2、3、4。5 是你的人脉问题。

**Phase 0 关键验证：第 2 项的物种分类器 benchmark 是整个方案最大的技术不确定点。** 如果 Apple Silicon 单张推理 > 100ms 或准确率 < 70%，整个"本地 ML + 2000 张 3 分钟"的承诺会动摇，需要回到 §10 D4 重新选型。这是 Phase 0 的 Go/No-Go 信号之一。

---

## 附录 A：v1 功能优先级（从 PRD 精简）

P0（必须发 v1）：Cull 全部 P0 + Polish 全部 P0 + Create 的 Social Collage + Personal Field Guide + Print-ready PDF + Share Sheet
P1（v1 争取）：Cull 的 Multi-Subject、Smart Filters；Polish 的 Annotation、Smart Placement；Create 的明信片、贺卡、月历、艺术版画、Life List 海报
P2（v1.5+）：Cull 统计、平台集成（Spotlight/Quick Look/Shortcuts）、Create 的 Wearables、POD 集成

## 附录 B：关键第三方服务依赖

**核心原则：** 默认运行路径不依赖任何云端推理服务。App 在完全离线环境下全功能可用（除首次启动下载模型）。

| 服务 | 用途 | 风险 | 备用方案 |
|---|---|---|---|
| eBird Taxonomy + 分布数据 | 物种分类 + 地理后验过滤 | 一年一次手动更新 | 若断，最新 snapshot 能用 |
| 开源模型权重来源（iNaturalist / NABirds / HuggingFace / 区域项目） | 物种分类器的初始权重 | 许可证 / 更新频率 | 多个候选；见 §10 D4 |
| 自建 CDN（hosting Core ML 模型） | 模型按需下载 | 可控 | S3 + CloudFront 标准组合 |
| Sentry 或 TelemetryDeck | 崩溃数据（用户 opt-in 后） | 标准 SaaS | 自建 oslog agg 也行 |
| Apple 开发者账号 | 代码签名 / notarization | 标准 | 无 |

**明确排除的：** Anthropic Claude Vision API、OpenAI Vision、Google Gemini Vision、任何云端物种识别服务、任何云端 AI 生成服务。这些不在 v1 的任何默认代码路径里。

---

*文档版本：0.2 — 2026-04-19*
*作者：Bruce & Claude (co-founder mode)*
*v0.2 变更：（1）ML 全本地化，移除所有云端物种识别路径；（2）暂缓所有商业化讨论（定价/分发/Wearables POD）；（3）新增地理覆盖开放决策 D4；（4）Phase 0 新增本地物种分类器 benchmark 作为 Go/No-Go 验证点*
*下一版触发：你的 review 反馈或关键技术验证失败时*
