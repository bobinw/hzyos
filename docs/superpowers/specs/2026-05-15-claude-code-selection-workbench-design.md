# Claude Code 选品工作台 — 设计规格说明

- **版本**: 1.0
- **日期**: 2026-05-15
- **状态**: 待评审

## 1. 概述

### 1.1 目标

创建一套新的 HTML 工具（`claude-selection-workbench.html`），让 Claude Code 作为选品顾问参与商品选品流程。与现有 `proposal-system.html` 和 `product-library-system-local.html` 互补。

### 1.2 核心价值

- 现有算法擅长数学优化（预算、毛利率约束），Claude Code 擅长理解客户画像、场景语义、选品理由
- 通过文件桥接实现 HTML 工具与 Claude Code CLI 的自动化协作
- 三种工作模式覆盖完整选品、辅助增强、方案评审全场景

## 2. 架构

### 2.1 整体架构

单文件 HTML 应用，和现有系统保持一致。部署方式：浏览器直接打开。

```
┌──────────────────────────────────────────────┐
│        claude-selection-workbench.html        │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │ 左侧栏    │  │ 主区域    │  │ 底部操作栏  │  │
│  │ 模式切换  │  │ 需求输入  │  │ 生成Prompt  │  │
│  │ 预筛条件  │  │ 参数微调  │  │ 加载结果    │  │
│  │ 桥接状态  │  │ 结果展示  │  │ 导出方案    │  │
│  └──────────┘  └──────────┘  └────────────┘  │
│                      ↕                        │
│              IndexedDB (ProductLibraryDB)      │
└──────────────────────────────────────────────┘
         ↕ 文件读写              ↕ 文件读写
┌────────────────────┐  ┌──────────────────────┐
│ selection-prompt   │  │ selection-result     │
│ .md                │  │ .json                │
└────────┬───────────┘  └──────────┬───────────┘
         │ 读取                    │ 写入
┌────────┴─────────────────────────┴───────────┐
│            watch-selection.sh                 │
│  监听 prompt 变化 → 调用 Claude Code CLI      │
│  → 等待输出 → 写入 result JSON                │
└──────────────────────────────────────────────┘
```

### 2.2 数据来源

直接从 IndexedDB (`ProductLibraryDB.products`) 读取全量商品数据，与现有两套系统共享同一数据库。不引入新的数据存储。

### 2.3 文件桥接

| 方向 | 文件 | 格式 | 说明 |
|------|------|------|------|
| HTML → Claude Code | `selection-prompt.md` | Markdown | 任务指令 + 需求 + 商品摘要表 |
| Claude Code → HTML | `selection-result.json` | JSON | 方案数组（含产品ID/理由/汇总） |

三种运行模式：
- **全自动**：监听脚本 `watch-selection.sh` 常驻后台，检测 prompt 文件变化自动调 Claude Code CLI，结果写回后 HTML 轮询加载
- **半自动**：无监听脚本，用户手动在 Claude Code 中输入一句指令引用 prompt 文件
- **手动**：复制粘贴 prompt 和结果，应急/微调场景

## 3. 三种工作模式

### 3.1 完整选品 (full-selection)

**场景**：从零开始，Claude Code 独立完成全流程。

- 输入：需求描述 + 预筛候选商品摘要 + 参数（方案数、预算、毛利率等）
- Claude Code 职责：理解客户画像、从候选池挑选产品、生成 N 套差异化方案、每件产品附选品理由、输出价格/毛利率汇总
- 输出：完整方案集（JSON）

### 3.2 辅助增强 (enhance)

**场景**：现有算法先生成粗方案，Claude Code 补充判断。

- 输入：需求 + 候选摘要 + 算法已生成的方案（产品列表）
- Claude Code 职责：评审方案合理性、给出差异化建议、替换不合适单品、补充选品理由和客户沟通话术
- 输出：增强后的方案集

### 3.3 方案评审 (review)

**场景**：方案已有，Claude Code 做质量把关。

- 输入：需求 + 候选摘要（对照）+ 待评审方案
- Claude Code 职责：检查品类覆盖、品牌集中度、价格/毛利率达标情况、指出问题单品并建议替换、给出总体评分
- 输出：评审报告

### 3.4 模式切换

左侧栏顶部三个 tab 切换。切换时保留需求描述和预筛条件。模式 2 需从现有系统导入方案，模式 3 需导入待评审方案。

## 4. 用户界面

### 4.1 整体布局

三列布局：
- **左侧栏（~270px）**: 模式切换 → 预筛条件（大类/品类/品牌逐级筛选）→ 文件桥接状态
- **主区域（flex）**: 需求输入（自由文本）→ 参数微调（可选）→ 结果展示（方案卡片 + 详情展开表格）
- **底部操作栏**: 生成 Prompt / 复制 Prompt / 加载结果 / 导出方案

### 4.2 预筛条件

**核心原则**：字段名和字段值全部从 IndexedDB 动态提取，不做硬编码。

| 筛选项 | 字段名来源 | 值来源 |
|--------|-----------|--------|
| 大类 | 系统字段 `大类` | 从 products 表 DISTINCT |
| 品类 | 系统字段 `品类` | 从 products 表 DISTINCT，按已选大类过滤 |
| 品牌 | 系统字段 `品牌` | 从 products 表 DISTINCT，按已选大类分组，支持搜索 |
| 预算范围 | - | 手动输入 min/max |
| 毛利率 | - | 手动输入下限 |
| 排除品牌 | - | 手动输入 |

品类值按已选大类分组显示，只展示相关品类的可选值。

### 4.3 需求输入

自由文本 textarea，占主区域上方，引导用户描述：客户是谁、什么场景、预算人数、特殊偏好。placeholder 给出示例。

### 4.4 参数微调

可选的结构化参数，以 chips/tags 形式显示在需求下方：
- 方案数量（默认 6）
- 预算/人
- 人数
- 目标毛利率
- 场景（端午/中秋/春节/日常...）
- 档次（高端/中高端/中端/性价比）
- 可添加自定义参数

参数值通过关键词匹配从需求文本中自动提取预填（如 "200/人" → 预算200，"端午" → 场景端午），用户可手动修改。

### 4.5 结果展示

- 方案卡片水平排列，可横向滚动
- 每张卡片显示：方案名称、产品数、人均成本、平均毛利率
- 点击卡片展开详情表格：产品名称、品牌、品类、供货价、零售价、毛利率、选品理由
- 支持方案对比视图（勾选 2-3 个方案并列对比）

## 5. 数据协议

### 5.1 Prompt 文件 (`selection-prompt.md`)

Markdown 格式，包含以下段落：
1. 工作模式声明
2. 客户需求描述（用户原文）
3. 选品参数（结构化）
4. 预筛条件摘要
5. 候选商品表（Markdown 表格，列：ID、产品名称、品牌、大类、品类、供货价、零售价、毛利率、规格、场景标签、档次）
6. 输出格式要求和约束

### 5.2 结果文件 (`selection-result.json`)

```json
{
  "generatedAt": "ISO 8601",
  "mode": "full-selection | enhance | review",
  "proposals": [
    {
      "id": "A",
      "name": "方案名称",
      "summary": "一句话描述",
      "targetPersona": "适合什么类型的客户",
      "products": [
        {
          "productId": "必填，必须在候选表中存在",
          "productName": "...",
          "brand": "...",
          "majorCategory": "...",
          "category": "...",
          "supplyPrice": 0,
          "retailPrice": 0,
          "margin": 0,
          "reason": "Claude Code 给出的选品理由"
        }
      ],
      "totals": {
        "productCount": 0,
        "totalCost": 0,
        "totalRetail": 0,
        "avgMargin": 0
      },
      "categoryBreakdown": {
        "大类名": { "count": 0, "cost": 0, "ratio": 0 }
      }
    }
  ],
  "globalNotes": "方案间差异说明"
}
```

**约束**：
- productId 必须来自候选表，不可编造
- reason 字段每件产品必填
- totals 和 categoryBreakdown 由 Claude Code 计算
- HTML 加载时校验 productId 有效性

### 5.3 容错处理

- JSON 解析失败 → 提示格式错误，展示原始文本
- productId 在库中不存在 → 标记为"已下架"，红色高亮
- 字段缺失 → 对应列显示 "-"
- 支持粘贴不完整 JSON 后手动修复再解析

## 6. 监听脚本

### 6.1 `watch-selection.sh`

Bash 脚本，终端常驻运行。逻辑：

```
监听 selection-prompt.md 的写入事件
  → 检测到新内容
  → 调用 claude -p "$(cat selection-prompt.md)" --print
  → 将输出写入 selection-result.json
  → HTML 轮询检测到结果文件更新 → 自动加载
```

脚本一次性启动，持续运行。退出终端或 Ctrl+C 停止。

## 7. 与现有系统的集成

### 7.1 数据共享

直接读写 ProductLibraryDB IndexedDB，无需导出导入。

### 7.2 方案导出

选品结果可导出到现有系统：
- 导出为 proposal-system.html 能识别的格式
- 通过复制 JSON 或直接写 IndexedDB 的 proposals 表

### 7.3 方案导入

辅助增强和方案评审模式支持从现有系统导入方案：
- 从 IndexedDB 的 proposals 表读取已有方案
- 或粘贴现有系统导出的方案数据

## 8. 技术约束

- 单文件 HTML，纯前端，无构建步骤
- 使用 IndexedDB API 直接读取 ProductLibraryDB
- 文件读写优先使用 File System Access API（用户授权后可直接写本地文件）；不支持时降级为 Blob 下载 + 手动复制粘贴
- 与现有两套系统保持一致的 UI 风格（暗色主题）
- 不支持 IE 浏览器

## 9. 未纳入范围

- 不修改现有 proposal-system.html 的选品算法
- 不修改产品库的数据结构
- 不做服务端部署
- 不支持多用户协作
