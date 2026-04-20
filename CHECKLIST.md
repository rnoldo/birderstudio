# Birder Studio — Cull 模块实施 Checklist

按阶段切分 Cull 模块。**每完成一项勾选一项**，stage 结束前所有 P0 必须勾掉。

商业化（定价、分发、Wearables POD）一律不在此 checklist 范围内。

---

## Stage 1: 基础脚手架 & 数据层（本次会话）

**目标：** "数据模型 + 数据库 + 领域核心"可编译、可测试、可扩展。不碰 UI。

### 1.1 工程骨架
- [x] 根 `Package.swift`（BirderCore + BirderUI library products）
- [x] `.gitignore`（Swift / Xcode / macOS 标准）
- [x] Swift 6 语言模式 + 严格并发
- [x] GRDB.swift 7.x 依赖
- [x] 本 `CHECKLIST.md` 首次提交

### 1.2 领域模型（pure Swift, Sendable）
- [x] `Common.swift`（EXIF / Coordinate / FileFormat 等值类型）
- [x] `Photo.swift`
- [x] `Session.swift`
- [x] `PhotoAnalysis.swift`
- [x] `BirdDetection.swift`
- [x] `Species.swift`
- [x] `PhotoRating.swift`
- [x] `EditSnapshot.swift` + `EditGraph.swift`
- [x] `Project.swift` + `ProjectPhoto`

### 1.3 GRDB 集成 & Schema v1
- [x] `Database` 类型（DatabaseQueue wrapper, actor-safe）
- [x] `DatabaseMigrator` + schema v1（§3.1 全部表）
- [x] FTS5 `species_fts` 虚拟表
- [x] 索引（photos.session_id + captured_at; photos.checksum; bird_detections.photo_id）
- [x] `DatabaseError`

### 1.4 Repository 层
- [x] `PhotoRepository`
- [x] `SessionRepository`
- [x] `AnalysisRepository`
- [x] `BirdDetectionRepository`
- [x] `SpeciesRepository`（FTS5 搜索）
- [x] `RatingRepository`
- [x] ValueObservation 接口（为 SwiftUI 预留）

### 1.5 设计系统基础
- [x] BirderUI 模块创建
- [x] `Spacing` / `Typography` / `ColorPalette` / `Motion` token
- [x] `Color(hex:)` 扩展

### 1.6 单元测试 + CI
- [x] 模型 Codable round-trip 测试
- [x] Database migration 测试
- [x] Repository CRUD 测试
- [x] GitHub Actions CI（`swift test` on macOS-15 runner）

### 1.7 Stage 1 验收
- [x] `swift build` 通过
- [x] `swift test` 全绿
- [x] git commit: "Stage 1: foundation + data layer"

---

## Stage 2: Import + Library（下次会话起）

**目标：** 用户能把一批 RAW 拖进来，看到照片网格（60fps）。

### 2.1 Import Service
- [x] `ImportService` (Sendable final class, TaskGroup with bounded concurrency)
- [x] Security-scoped bookmark 生成 + 解析 + stale 处理 (`BookmarkStore`)
- [x] TaskGroup 并行导入（maxConcurrency = CPU 核数，默认 4 起）
- [x] Checksum 去重（first-1MB SHA-256 + file size，通过 `PhotoRepository.findByChecksum`）
- [x] EXIF 提取（`EXIFExtractor`：ImageIO metadata, 兼容 CR3 `ISOSpeed`）
- [x] 缩略图生成（256px HEIC via CGImageSource, embedded-first）
- [x] 预览图生成（1200px HEIC）
- [x] Import 进度 AsyncStream（`ImportEvent`）
- [x] 单元测试：真实 23 CR3 样本（benchmark: 0.82s / 36ms per photo）

### 2.2 App Shell（SPM executable）
- [x] SPM `BirderApp` executableTarget（避免依赖 Xcode 工程）
- [x] `@main` SwiftUI App + WindowGroup
- [x] `AppEnvironment`（DB / storage / repos / import service / bootstrap）
- [x] 主窗口 + NavigationSplitView（sidebar / detail）
- [x] 加载态 / 错误态 / 主壳切换
- [x] Session Sidebar：`observeAll()` AsyncSequence + 选中绑定
- [x] Session CRUD UI：创建 / 删除 / 选中

### 2.3 Drag & Drop Import UI
- [x] `ImportCoordinator` @MainActor ObservableObject（进度 / 计数 / 错误）
- [x] `.onDrop(of: [.fileURL])` → 格式过滤 → `ImportService.imports(...)`
- [x] 空态大号 drop zone + 导入中进度条 + 计数器
- [x] `PhotoRepository.observeBySession` 驱动实时照片数

### 2.4 Photo Grid（LazyVGrid）
- [x] `PhotoGridView` LazyVGrid（adaptive 220–280px）
- [x] `ThumbnailCache`（MainActor `NSCache<NSString, NSImage>` + 异步 disk read）
- [x] 缩略图 cell：RAW 标签、capture 时间、ISO/shutter/aperture tags
- [x] 选中高亮（amber 边框 + 阴影）
- [x] ScrollViewReader 自动滚动到选中
- [ ] NSCollectionView 迁移（需要时）+ 60fps profiling
- [ ] 多选

### 2.5 详情视图
- [x] `PhotoPreviewPane`：1200px HEIC 预览 + 右侧 EXIF inspector
- [x] 键盘左右切换 + Esc 关闭
- [x] `HSplitView` 可调节大图 + filmstrip grid
- [x] EXIF 分组：Capture / Exposure / File
- [ ] 缩放 / 1:1 / fit-to-window

### 2.6 Stage 2 验收
- [x] 23 CR3 样本导入 benchmark（0.82s / 36ms per photo）
- [x] `swift build` / `swift run BirderApp` 通过
- [x] Commit

---

## Stage 3: 分析管线

**目标：** 照片导入后自动 ML 分析，结果供 Cull 使用。

### 3.1 Analysis Service
- [ ] `AnalysisService` actor
- [ ] `AnalysisPipeline`（bbox / quality / feature print）
- [ ] 后台队列 + 优先级
- [ ] 分析进度 AsyncStream

### 3.2 Quality 评分（无需 ML 模型）
- [ ] Laplacian variance
- [ ] 曝光直方图（CIAreaHistogram）
- [ ] 构图（saliency + rule-of-thirds 距离）
- [ ] 加权合成
- [ ] Session 百分位归一化

### 3.3 Feature Print
- [ ] `VNGenerateImageFeaturePrintRequest` 封装
- [ ] 128 维向量距离计算
- [ ] BLOB 序列化 / 反序列化

### 3.4 Bbox 检测
- [ ] Core ML 模型加载 framework
- [ ] 模型按需下载 service
- [ ] 推理封装
- [ ] 归一化处理
- [ ] **Phase 0 关键 benchmark：准确率 + 速度**

### 3.5 场景分组
- [ ] 时间聚类（2s gap）
- [ ] Feature print 距离矩阵
- [ ] 层次聚类
- [ ] 每场景最佳
- [ ] 阈值可配置

### 3.6 Stage 3 验收
- [ ] 2000 张样本照片 3 分钟内分析完
- [ ] Commit

---

## Stage 4: Cull UI

**目标：** 键盘驱动、即时响应的筛选体验。

- [ ] Cull 主视图布局（film strip + canvas + inspector）
- [ ] 键盘导航（← → 切图，↑ ↓ 切场景）
- [ ] Accept / Reject / Star / Flag + 动效
- [ ] 场景最佳视觉标识
- [ ] A/B 对比视图
- [ ] Bbox overlay 渲染
- [ ] Session 统计条
- [ ] Cmd+K 全局搜索
- [ ] 撤销 / 重做历史

---

## Stage 5: 物种识别 & 打磨

- [ ] 物种分类 Core ML 模型集成
- [ ] §10 D4 决策执行（区域包）
- [ ] 物种手动修正 UI
- [ ] eBird 地理后验过滤
- [ ] 智能筛选器
- [ ] 批量操作
- [ ] 错误 / 空 / 加载态完整设计
- [ ] 10x 打磨 round
