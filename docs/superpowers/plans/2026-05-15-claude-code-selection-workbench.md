# Claude Code 选品工作台 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 `claude-selection-workbench.html` 单文件应用，实现三种选品模式 + IndexedDB 数据读取 + 动态预筛 + 文件桥接 + 结果展示。

**Architecture:** 单文件 HTML，纯前端，与现有 `ProductLibraryDB` IndexedDB (V10) 共享数据。三列布局：左侧模式/预筛，中间需求/结果，底部操作栏。通过文件读写（File System Access API）+ 剪贴板双通道与 Claude Code 桥接。

**Tech Stack:** Vanilla JS, IndexedDB API, File System Access API, Clipboard API, CSS Grid/Flexbox, 暗色主题

**Spec:** `docs/superpowers/specs/2026-05-15-claude-code-selection-workbench-design.md`

---

### Task 1: HTML 骨架 + IndexedDB 连接

**Files:**
- Create: `claude-selection-workbench.html`

- [ ] **Step 1: 创建 HTML 文件骨架**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude Code 选品工作台</title>
<style>
  :root {
    --bg: #1a1a2e;
    --panel: #16213e;
    --card: #0f3460;
    --accent: #e94560;
    --green: #4ecca3;
    --text: #e0e0e0;
    --muted: #888;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg); color: var(--text); min-height: 100vh;
  }
  .app { display: flex; flex-direction: column; height: 100vh; }
  .topbar { display: flex; align-items: center; justify-content: space-between;
    padding: 10px 16px; background: var(--bg); border-bottom: 1px solid #2a2a4a; }
  .topbar h1 { font-size: 16px; font-weight: 600; }
  .main { display: flex; flex: 1; overflow: hidden; }
  .sidebar { width: 280px; flex-shrink: 0; overflow-y: auto; padding: 12px;
    background: var(--panel); border-right: 1px solid #2a2a4a; }
  .content { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
  .content-area { flex: 1; overflow-y: auto; padding: 12px; }
  .bottombar { padding: 8px 16px; background: var(--panel); border-top: 1px solid #2a2a4a;
    display: flex; gap: 8px; align-items: center; }
  .section-title { font-size: 10px; text-transform: uppercase; color: var(--muted);
    letter-spacing: 1px; margin-bottom: 6px; }
  .panel-box { background: var(--card); border-radius: 8px; padding: 10px; margin-bottom: 10px; }
  button, .btn {
    background: var(--card); color: var(--text); border: 1px solid #3a3a5a;
    padding: 6px 14px; border-radius: 6px; cursor: pointer; font-size: 12px;
    white-space: nowrap;
  }
  button:hover { background: #1a3a6a; }
  button.primary { background: var(--accent); border-color: var(--accent); color: #fff; }
  button.primary:hover { background: #d63850; }
  button.green { background: var(--green); border-color: var(--green); color: #000; }
  button.small { padding: 3px 8px; font-size: 10px; }
  textarea, input[type="text"], input[type="number"] {
    background: var(--card); color: var(--text); border: 1px solid #3a3a5a;
    border-radius: 6px; padding: 8px; font-size: 12px; width: 100%;
    font-family: inherit;
  }
  textarea:focus, input:focus { outline: none; border-color: var(--accent); }
  .tag {
    display: inline-flex; align-items: center; gap: 4px;
    padding: 3px 8px; font-size: 10px; border-radius: 12px;
    background: var(--card); border: 1px solid #3a3a5a;
    cursor: pointer; user-select: none;
  }
  .tag.selected { border-color: var(--accent); color: var(--accent); }
  .tag.active { border-color: var(--green); color: var(--green); }
  .chip-group { display: flex; flex-wrap: wrap; gap: 4px; }
  .mode-tab { padding: 6px 10px; border-radius: 6px; cursor: pointer; font-size: 11px;
    border-left: 3px solid transparent; transition: all 0.15s; }
  .mode-tab.active { background: var(--card); border-left-color: var(--accent); }
  .mode-tab:not(.active) { color: var(--muted); }
  .status-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 4px; }
  .status-dot.ready { background: var(--green); }
  .status-dot.waiting { background: #f0a500; animation: pulse 1.5s infinite; }
  @keyframes pulse { 0%,100% { opacity:1; } 50% { opacity:0.3; } }
  .hidden { display: none !important; }
  /* Proposal cards */
  .cards-row { display: flex; gap: 8px; overflow-x: auto; padding-bottom: 8px; }
  .proposal-card {
    min-width: 220px; background: var(--card); border-radius: 8px;
    padding: 12px; cursor: pointer; border-top: 3px solid transparent;
    flex-shrink: 0;
  }
  .proposal-card:hover { background: #1a3a6a; }
  .proposal-card.selected { border-top-color: var(--accent); }
  .proposal-card .name { font-size: 13px; font-weight: 600; }
  .proposal-card .stats { font-size: 10px; color: var(--green); margin-top: 4px; }
  .proposal-card .preview { font-size: 9px; color: var(--muted); margin-top: 4px; line-height: 1.4; }
  /* Detail table */
  .detail-table { width: 100%; font-size: 11px; border-collapse: collapse; }
  .detail-table th { text-align: left; color: var(--muted); padding: 4px 6px;
    border-bottom: 1px solid #2a2a4a; font-weight: 500; font-size: 10px; }
  .detail-table td { padding: 4px 6px; border-bottom: 1px solid #1a1a2e; }
  .detail-table tr.warning td { background: rgba(233,69,96,0.1); }
  .file-path { font-size: 10px; color: var(--muted); font-family: monospace; }
  .toast { position: fixed; top: 20px; right: 20px; padding: 10px 18px;
    border-radius: 8px; font-size: 12px; z-index: 999; animation: fadeIn 0.2s; }
  .toast.success { background: var(--green); color: #000; }
  .toast.error { background: var(--accent); color: #fff; }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(-8px); } }
  /* File System Access API polyfill notice */
  .fsa-notice { font-size: 10px; color: #f0a500; margin-top: 4px; }
</style>
</head>
<body>
<div class="app">
  <div class="topbar">
    <div style="display:flex;align-items:center;gap:12px;">
      <h1>Claude Code 选品工作台</h1>
      <span id="productCount" class="tag" style="cursor:default;"></span>
    </div>
    <div style="display:flex;gap:6px;">
      <span id="bridgeStatus" style="font-size:10px;color:var(--muted);"></span>
    </div>
  </div>
  <div class="main">
    <div class="sidebar" id="sidebar">
      <!-- Mode switcher -->
      <div class="section-title">工作模式</div>
      <div class="panel-box" id="modeSwitcher">
        <div class="mode-tab active" data-mode="full">🔄 完整选品</div>
        <div class="mode-tab" data-mode="enhance">🔧 辅助增强</div>
        <div class="mode-tab" data-mode="review">✅ 方案评审</div>
      </div>
      <!-- Pre-filter -->
      <div class="section-title">预筛条件</div>
      <div class="panel-box" id="preFilter"></div>
      <!-- Bridge status -->
      <div class="section-title">文件桥接</div>
      <div class="panel-box" id="bridgePanel">
        <div style="font-size:10px;color:var(--muted);line-height:1.6;">
          <div>📤 <span class="file-path">selection-prompt.md</span></div>
          <div>📥 <span class="file-path">selection-result.json</span></div>
          <div id="bridgeState" style="margin-top:4px;">● 就绪</div>
        </div>
      </div>
    </div>
    <div class="content">
      <div class="content-area" id="contentArea">
        <!-- Requirement input -->
        <div class="section-title">需求描述</div>
        <textarea id="requirementInput" rows="4" placeholder="描述客户是谁、什么场景、预算人数、特殊偏好。&#10;例如：杭州一家互联网公司，500人，端午福利，预算200/人。员工偏年轻，喜欢新潮实用的东西。"></textarea>
        <!-- Params -->
        <div class="section-title" style="margin-top:12px;">参数微调（可选）</div>
        <div class="panel-box">
          <div class="chip-group" id="paramChips"></div>
        </div>
        <!-- Results -->
        <div class="section-title" style="margin-top:12px;">选品结果</div>
        <div id="resultsArea">
          <div style="color:var(--muted);font-size:12px;padding:20px;text-align:center;">
            输入需求 → 生成 Prompt → Claude Code 分析 → 加载结果
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="bottombar">
    <button class="primary" id="btnGenerate">📤 生成 Prompt 文件</button>
    <button id="btnCopyPrompt">📋 复制 Prompt</button>
    <button class="green" id="btnLoadResult">📥 加载结果文件</button>
    <button id="btnPasteResult">📋 粘贴结果</button>
    <span style="flex:1;"></span>
    <button id="btnExport" class="small" disabled>导出到现有系统</button>
  </div>
</div>
<div id="toastContainer"></div>
<script>
// ===== 全局状态 =====
const DB_NAME = 'ProductLibraryDB';
const DB_VERSION = 10;
let db = null;
let allProducts = [];
let filteredProducts = [];
let currentMode = 'full';
let selectionResult = null;
let promptFilePath = 'selection-prompt.md';
let resultFilePath = 'selection-result.json';

// ===== 数据库 =====
function initDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      db = request.result;
      db.onversionchange = () => { db.close(); db = null; };
      resolve(db);
    };
  });
}

function loadAllProducts() {
  return new Promise((resolve, reject) => {
    const tx = db.transaction('products', 'readonly');
    const store = tx.objectStore('products');
    const request = store.getAll();
    request.onsuccess = () => resolve(request.result || []);
    request.onerror = () => reject(request.error);
  });
}

// ===== 应用入口 =====
(async function init() {
  try {
    await initDB();
    allProducts = await loadAllProducts();
    filteredProducts = [...allProducts];
    document.getElementById('productCount').textContent =
      `📦 ${allProducts.length.toLocaleString()} 条商品`;
    document.getElementById('bridgeStatus').textContent = 'DB 已连接';
    buildPreFilter();
    buildParamChips();
    document.getElementById('requirementInput').addEventListener('input', extractParamsFromText);
  } catch (e) {
    document.getElementById('productCount').textContent = '❌ DB 连接失败';
    document.getElementById('bridgeStatus').textContent = '请在同源下打开（与商品库同一域名）';
  }
})();
</script>
</body>
</html>
```

- [ ] **Step 2: 在浏览器中打开文件，验证**

打开 `claude-selection-workbench.html`，确认：页面加载成功，顶部显示商品数量，左侧栏三个区域可见。

- [ ] **Step 3: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: 选品工作台骨架 + IndexedDB 连接"
```

---

### Task 2: 动态预筛引擎

**Files:**
- Modify: `claude-selection-workbench.html` (replace `buildPreFilter` placeholder)

- [ ] **Step 1: 实现动态字段提取 + 预筛 UI 构建**

替换骨架中的 `buildPreFilter` 函数：

```javascript
// 预筛状态
let preFilter = {
  majorCategories: new Set(),   // 大类选中
  categories: new Set(),        // 品类选中
  brands: new Set(),            // 品牌选中
  selectedBrandsByCategory: {}, // { 大类: [品牌名] }
  budgetMin: null,
  budgetMax: null,
  marginMin: null,
  excludedBrands: new Set()
};

// 从产品数据中提取所有大类的唯一值
function getMajorCategories() {
  const values = new Set();
  allProducts.forEach(p => {
    if (p.majorCategory) values.add(p.majorCategory);
  });
  return [...values].sort();
}

// 按已选大类，提取关联的品类唯一值
function getCategoriesForMajors(majorCats) {
  const values = new Set();
  const targetMajors = majorCats.size > 0 ? majorCats : new Set(getMajorCategories());
  allProducts.forEach(p => {
    if (targetMajors.has(p.majorCategory) && p.category) {
      values.add(p.category);
    }
  });
  return [...values].sort();
}

// 按大类分组提取品牌
function getBrandsByMajor(majorCats) {
  const map = {};
  const targetMajors = majorCats.size > 0 ? majorCats : new Set(getMajorCategories());
  allProducts.forEach(p => {
    if (targetMajors.has(p.majorCategory) && p.brand) {
      if (!map[p.majorCategory]) map[p.majorCategory] = new Set();
      map[p.majorCategory].add(p.brand);
    }
  });
  // 转换为排序数组
  const result = {};
  for (const [maj, brands] of Object.entries(map)) {
    result[maj] = [...brands].sort();
  }
  return result;
}

function buildPreFilter() {
  const container = document.getElementById('preFilter');
  const majorCats = getMajorCategories();
  const selMajors = preFilter.majorCategories;

  let html = '';

  // --- 大类 ---
  html += '<div style="margin-bottom:8px;">';
  html += '<div style="font-size:10px;color:var(--muted);margin-bottom:4px;">大类';
  if (selMajors.size > 0) {
    html += ` <span style="color:var(--green);">${selMajors.size}/${majorCats.length} 已选</span>`;
  }
  html += '</div><div class="chip-group">';
  majorCats.forEach(maj => {
    const sel = selMajors.has(maj) ? ' selected' : '';
    html += `<span class="tag${sel}" data-filter="major" data-value="${escapeHtml(maj)}">${escapeHtml(maj)}</span>`;
  });
  html += '</div></div>';

  // --- 品类（按选中大类分组） ---
  html += '<div style="margin-bottom:8px;">';
  html += '<div style="font-size:10px;color:var(--muted);margin-bottom:4px;">品类';
  if (preFilter.categories.size > 0) {
    html += ` <span style="color:var(--green);">${preFilter.categories.size} 已选</span>`;
  }
  html += '</div>';
  html += '<div style="max-height:160px;overflow-y:auto;">';

  const displayMajors = selMajors.size > 0 ? selMajors : new Set(majorCats);
  displayMajors.forEach(maj => {
    html += `<div style="font-size:9px;color:var(--green);margin:4px 0 2px;">${escapeHtml(maj)} →</div>`;
    html += '<div class="chip-group">';
    // Get categories that have products in this major
    const catSet = new Set();
    allProducts.forEach(p => {
      if (p.majorCategory === maj && p.category) catSet.add(p.category);
    });
    [...catSet].sort().forEach(cat => {
      const sel = preFilter.categories.has(cat) ? ' selected' : '';
      html += `<span class="tag${sel}" data-filter="category" data-value="${escapeHtml(cat)}">${escapeHtml(cat)}</span>`;
    });
    html += '</div>';
  });
  html += '</div></div>';

  // --- 品牌（按大类分组） ---
  html += '<div style="margin-bottom:8px;">';
  html += '<div style="font-size:10px;color:var(--muted);margin-bottom:4px;">品牌 <span style="color:var(--muted);">· 可选</span></div>';
  html += '<div style="max-height:140px;overflow-y:auto;">';
  displayMajors.forEach(maj => {
    html += `<div style="font-size:9px;color:var(--green);margin:4px 0 2px;">${escapeHtml(maj)}:</div>`;
    html += `<input type="text" class="brand-search" data-major="${escapeHtml(maj)}"
      placeholder="🔍 搜索品牌..." style="font-size:9px;padding:3px 6px;margin-bottom:3px;"
      oninput="filterBrands(this)">`;
    html += `<div class="chip-group brand-chips" data-major="${escapeHtml(maj)}">`;
    const brands = getBrandsByMajor(new Set([maj]))[maj] || [];
    brands.forEach(brand => {
      const sel = preFilter.brands.has(brand) ? ' selected' : '';
      html += `<span class="tag${sel}" data-filter="brand" data-value="${escapeHtml(brand)}">${escapeHtml(brand)}</span>`;
    });
    html += '</div>';
  });
  html += '</div></div>';

  // --- 其他条件 ---
  html += '<div style="margin-bottom:6px;">';
  html += '<div style="font-size:10px;color:var(--muted);margin-bottom:4px;">其他条件</div>';
  html += `<input type="number" id="filterBudgetMin" placeholder="预算下限 (元/人)" style="margin-bottom:4px;font-size:10px;"
    value="${preFilter.budgetMin || ''}" onchange="updateBudgetFilter()">`;
  html += `<input type="number" id="filterBudgetMax" placeholder="预算上限 (元/人)" style="margin-bottom:4px;font-size:10px;"
    value="${preFilter.budgetMax || ''}" onchange="updateBudgetFilter()">`;
  html += `<input type="number" id="filterMarginMin" placeholder="毛利率下限 (%)" style="margin-bottom:4px;font-size:10px;"
    value="${preFilter.marginMin || ''}" onchange="updateMarginFilter()">`;
  html += '<input type="text" id="filterExcludeBrands" placeholder="排除品牌（逗号分隔）" style="font-size:10px;" onchange="updateExcludeFilter()">';
  html += '</div>';

  // --- 筛选结果计数 ---
  html += '<div style="font-size:10px;color:var(--green);font-weight:600;" id="filteredCount"></div>';

  container.innerHTML = html;
  updateFilteredCount();

  // 绑定标签点击事件
  container.querySelectorAll('.tag[data-filter]').forEach(tag => {
    tag.addEventListener('click', () => toggleFilter(tag));
  });
}
```

- [ ] **Step 2: 实现筛选逻辑（toggleFilter + applyFilters）**

```javascript
function toggleFilter(el) {
  const type = el.dataset.filter;
  const value = el.dataset.value;

  if (type === 'major') {
    if (preFilter.majorCategories.has(value)) {
      preFilter.majorCategories.delete(value);
    } else {
      preFilter.majorCategories.add(value);
    }
    // 清除不在选中大类下的品类和品牌
    preFilter.categories.clear();
    preFilter.brands.clear();
  } else if (type === 'category') {
    if (preFilter.categories.has(value)) {
      preFilter.categories.delete(value);
    } else {
      preFilter.categories.add(value);
    }
  } else if (type === 'brand') {
    if (preFilter.brands.has(value)) {
      preFilter.brands.delete(value);
    } else {
      preFilter.brands.add(value);
    }
  }
  buildPreFilter();
}

function applyFilters() {
  let result = [...allProducts];

  // 大类过滤
  if (preFilter.majorCategories.size > 0) {
    result = result.filter(p => preFilter.majorCategories.has(p.majorCategory));
  }
  // 品类过滤
  if (preFilter.categories.size > 0) {
    result = result.filter(p => preFilter.categories.has(p.category));
  }
  // 品牌过滤（白名单）
  if (preFilter.brands.size > 0) {
    result = result.filter(p => preFilter.brands.has(p.brand));
  }
  // 预算范围（使用集采价作为供货价参考）
  if (preFilter.budgetMin != null) {
    result = result.filter(p => p.purchasePrice && p.purchasePrice >= preFilter.budgetMin * 0.3);
  }
  if (preFilter.budgetMax != null) {
    result = result.filter(p => p.purchasePrice && p.purchasePrice <= preFilter.budgetMax * 0.8);
  }
  // 毛利率
  if (preFilter.marginMin != null) {
    result = result.filter(p => {
      if (!p.purchasePrice || !p.retailPrice || p.retailPrice === 0) return true;
      const margin = ((p.retailPrice - p.purchasePrice) / p.retailPrice) * 100;
      return margin >= preFilter.marginMin;
    });
  }
  // 排除品牌
  if (preFilter.excludedBrands.size > 0) {
    result = result.filter(p => !preFilter.excludedBrands.has(p.brand));
  }

  return result;
}

function updateFilteredCount() {
  filteredProducts = applyFilters();
  const el = document.getElementById('filteredCount');
  if (el) {
    el.innerHTML = `● 筛选后: ${filteredProducts.length.toLocaleString()} 条候选`;
  }
}

function updateBudgetFilter() {
  preFilter.budgetMin = parseFloat(document.getElementById('filterBudgetMin').value) || null;
  preFilter.budgetMax = parseFloat(document.getElementById('filterBudgetMax').value) || null;
  updateFilteredCount();
}
function updateMarginFilter() {
  preFilter.marginMin = parseFloat(document.getElementById('filterMarginMin').value) || null;
  updateFilteredCount();
}
function updateExcludeFilter() {
  const val = document.getElementById('filterExcludeBrands').value;
  preFilter.excludedBrands = new Set(val.split(',').map(s => s.trim()).filter(Boolean));
  updateFilteredCount();
}

function filterBrands(input) {
  const major = input.dataset.major;
  const query = input.value.toLowerCase();
  const chips = input.parentElement.querySelectorAll('.brand-chips .tag');
  chips.forEach(chip => {
    const brand = chip.dataset.value;
    chip.style.display = brand.toLowerCase().includes(query) ? '' : 'none';
  });
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
```

- [ ] **Step 3: 在浏览器中测试预筛交互**

打开页面，验证：
- 大类标签点击可选中/取消
- 品类按选中大类分组显示
- 品牌搜索框输入可过滤
- 筛选后计数更新

- [ ] **Step 4: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: 动态预筛引擎（大类/品类/品牌三级筛选）"
```

---

### Task 3: 三种工作模式 + 参数配置

**Files:**
- Modify: `claude-selection-workbench.html` (mode switcher + param chips)

- [ ] **Step 1: 实现模式切换逻辑**

```javascript
// 模式切换
document.getElementById('modeSwitcher').addEventListener('click', (e) => {
  const tab = e.target.closest('.mode-tab');
  if (!tab) return;
  currentMode = tab.dataset.mode;
  document.querySelectorAll('.mode-tab').forEach(t => t.classList.remove('active'));
  tab.classList.add('active');

  // 切换时调整 UI
  const enhanceArea = document.getElementById('enhanceImportArea');
  const reviewArea = document.getElementById('reviewImportArea');
  if (currentMode === 'enhance') {
    enhanceArea.classList.remove('hidden');
    reviewArea.classList.add('hidden');
  } else if (currentMode === 'review') {
    enhanceArea.classList.add('hidden');
    reviewArea.classList.remove('hidden');
  } else {
    enhanceArea.classList.add('hidden');
    reviewArea.classList.add('hidden');
  }
});
```

在需求输入框下方添加导入区域（初始隐藏）：

```html
<!-- 辅助增强：导入已有方案 -->
<div id="enhanceImportArea" class="panel-box hidden" style="margin-top:8px;">
  <div style="font-size:11px;color:var(--muted);margin-bottom:4px;">
    导入现有算法方案（从 proposal-system.html 复制）</div>
  <textarea id="enhanceInput" rows="3" placeholder="粘贴方案 JSON 或从 IndexedDB proposals 表加载..."
    style="font-size:10px;"></textarea>
  <button class="small" style="margin-top:4px;" onclick="loadProposalsFromDB()">从 DB 加载方案</button>
</div>
<!-- 方案评审：导入待评审方案 -->
<div id="reviewImportArea" class="panel-box hidden" style="margin-top:8px;">
  <div style="font-size:11px;color:var(--muted);margin-bottom:4px;">
    导入待评审方案</div>
  <textarea id="reviewInput" rows="3" placeholder="粘贴待评审方案 JSON..."
    style="font-size:10px;"></textarea>
  <button class="small" style="margin-top:4px;" onclick="loadProposalsFromDB()">从 DB 加载方案</button>
</div>
```

- [ ] **Step 2: 实现参数配置 + 需求文本自动提取**

```javascript
let selectionParams = {
  proposalCount: 6,
  budgetPerPerson: 200,
  peopleCount: 500,
  targetMargin: 30,
  scene: '',
  tier: ''
};

function buildParamChips() {
  const container = document.getElementById('paramChips');
  const params = [
    { key: 'proposalCount', label: '方案数', value: selectionParams.proposalCount, type: 'number' },
    { key: 'budgetPerPerson', label: '预算/人', value: selectionParams.budgetPerPerson, suffix: '元' },
    { key: 'peopleCount', label: '人数', value: selectionParams.peopleCount, suffix: '人' },
    { key: 'targetMargin', label: '毛利率', value: selectionParams.targetMargin, suffix: '%' },
    { key: 'scene', label: '场景', value: selectionParams.scene, placeholder: '端午/中秋/春节...' },
    { key: 'tier', label: '档次', value: selectionParams.tier, placeholder: '中高端/中端/性价比' }
  ];

  container.innerHTML = params.map(p => {
    if (p.key === 'scene' || p.key === 'tier') {
      return `<span class="tag" data-param="${p.key}" contenteditable="true"
        onblur="updateParam('${p.key}', this.textContent)"
        onkeydown="if(event.key==='Enter'){event.preventDefault();this.blur();}">${p.value || p.placeholder}</span>`;
    }
    return `<span class="tag" data-param="${p.key}">
      ${p.label}: <input type="${p.type || 'number'}" value="${p.value}"
        style="width:50px;background:transparent;border:none;color:inherit;font-size:10px;padding:0;"
        onchange="updateParam('${p.key}', this.value)">${p.suffix || ''}</span>`;
  }).join('');

  // 添加自定义参数按钮
  container.insertAdjacentHTML('beforeend',
    '<button class="btn small" onclick="addCustomParam()">+ 添加</button>');
}

function updateParam(key, value) {
  if (key === 'proposalCount' || key === 'budgetPerPerson' ||
      key === 'peopleCount' || key === 'targetMargin') {
    selectionParams[key] = parseFloat(value) || 0;
  } else {
    selectionParams[key] = value;
  }
}

function extractParamsFromText() {
  const text = document.getElementById('requirementInput').value;

  // 预算提取：200/人、预算200、200元/人
  const budgetMatch = text.match(/(\d+)\s*(?:元|块)?\s*\/\s*(?:人|每人)/);
  if (budgetMatch) {
    selectionParams.budgetPerPerson = parseInt(budgetMatch[1]);
  }
  // 人数提取：500人、500名员工、员工500
  const peopleMatch = text.match(/(\d+)\s*(?:人|名|位)/);
  if (peopleMatch && parseInt(peopleMatch[1]) > 10) {
    selectionParams.peopleCount = parseInt(peopleMatch[1]);
  }
  // 毛利率提取
  const marginMatch = text.match(/毛利(?:率)?\s*(?:≥|>=|>)?\s*(\d+)\s*%/);
  if (marginMatch) {
    selectionParams.targetMargin = parseInt(marginMatch[1]);
  }
  // 场景提取
  const scenes = ['端午', '中秋', '春节', '年节', '新年', '日常', '生日', '三八', '五一', '国庆', '圣诞'];
  for (const s of scenes) {
    if (text.includes(s)) { selectionParams.scene = s; break; }
  }
  // 档次提取
  const tiers = ['高端', '中高端', '中端', '性价比', '平价'];
  for (const t of tiers) {
    if (text.includes(t)) { selectionParams.tier = t; break; }
  }

  buildParamChips();
}

let customParamCounter = 0;
function addCustomParam() {
  customParamCounter++;
  const container = document.getElementById('paramChips');
  const addBtn = container.querySelector('button');
  const span = document.createElement('span');
  span.className = 'tag';
  span.contentEditable = 'true';
  span.dataset.custom = `custom_${customParamCounter}`;
  span.textContent = '新参数';
  span.addEventListener('blur', () => { /* no-op, just visual */ });
  span.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); span.blur(); }
  });
  container.insertBefore(span, addBtn);
}
```

在 `init()` 函数中添加：

```javascript
document.getElementById('requirementInput').addEventListener('input', () => {
  extractParamsFromText();
});
```

- [ ] **Step 3: 实现从现有系统加载方案**

```javascript
async function loadProposalsFromDB() {
  try {
    if (!db) { showToast('数据库未连接', 'error'); return; }
    const tx = db.transaction('proposals', 'readonly');
    const store = tx.objectStore('proposals');
    const all = await new Promise((resolve, reject) => {
      const req = store.getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => reject(req.error);
    });
    if (all.length === 0) {
      showToast('proposals 表中无方案', 'error'); return;
    }
    const json = JSON.stringify(all, null, 2);
    if (currentMode === 'enhance') {
      document.getElementById('enhanceInput').value = json;
    } else {
      document.getElementById('reviewInput').value = json;
    }
    showToast(`已加载 ${all.length} 套方案`, 'success');
  } catch (e) {
    showToast('加载失败: ' + e.message, 'error');
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: 三种工作模式 + 参数配置 + 需求文本自动提取"
```

---

### Task 4: Prompt 生成 + 文件写入 + 剪贴板

**Files:**
- Modify: `claude-selection-workbench.html` (generatePrompt, file write, clipboard)

- [ ] **Step 1: 实现 Prompt 生成函数**

```javascript
function buildPromptMarkdown() {
  const requirement = document.getElementById('requirementInput').value.trim();
  if (!requirement) { showToast('请先输入需求描述', 'error'); return null; }
  if (filteredProducts.length === 0) { showToast('筛选后无候选商品', 'error'); return null; }

  const modeLabels = {
    full: '完整选品（从候选池中独立挑选，生成 N 套差异化方案）',
    enhance: '辅助增强（基于已有方案进行润色、替换和补充）',
    review: '方案评审（评审已有方案的合理性并给出改进建议）'
  };

  let md = '# 选品任务\n\n';
  md += `## 工作模式\n${modeLabels[currentMode]}\n\n`;
  md += `## 客户需求\n${requirement}\n\n`;

  // 参数
  md += '## 选品参数\n';
  md += `- 方案数量: ${selectionParams.proposalCount}\n`;
  if (selectionParams.budgetPerPerson) md += `- 预算: ${selectionParams.budgetPerPerson} 元/人\n`;
  if (selectionParams.peopleCount) md += `- 人数: ${selectionParams.peopleCount}\n`;
  if (selectionParams.targetMargin) md += `- 目标毛利率: ≥${selectionParams.targetMargin}%\n`;
  if (selectionParams.scene) md += `- 场景: ${selectionParams.scene}\n`;
  if (selectionParams.tier) md += `- 档次: ${selectionParams.tier}\n`;
  md += '\n';

  // 预筛条件
  md += '## 预筛条件\n';
  if (preFilter.majorCategories.size > 0) {
    md += `- 大类: ${[...preFilter.majorCategories].join(', ')}\n`;
  }
  if (preFilter.categories.size > 0) {
    md += `- 品类: ${[...preFilter.categories].join(', ')}\n`;
  }
  if (preFilter.brands.size > 0) {
    md += `- 品牌偏好: ${[...preFilter.brands].join(', ')}\n`;
  }
  if (preFilter.budgetMin != null || preFilter.budgetMax != null) {
    md += `- 预算范围: ${preFilter.budgetMin || 0} - ${preFilter.budgetMax || '不限'} 元/人\n`;
  }
  if (preFilter.marginMin != null) {
    md += `- 毛利率 ≥ ${preFilter.marginMin}%\n`;
  }
  if (preFilter.excludedBrands.size > 0) {
    md += `- 排除品牌: ${[...preFilter.excludedBrands].join(', ')}\n`;
  }
  md += '\n';

  // 候选商品表（选核心字段，压缩行数）
  const maxRows = 2000;
  const products = filteredProducts.slice(0, maxRows);
  md += `## 候选商品 (${products.length} 条`;
  if (filteredProducts.length > maxRows) md += `，已截断至 ${maxRows}`;
  md += ')\n\n';

  md += '| ID | 产品名称 | 品牌 | 大类 | 品类 | 供货价 | 零售价 | 毛利率 | 规格 | 场景标签 | 档次 |\n';
  md += '|---|---|---|---|---|---|---|---|---|---|\n';

  products.forEach(p => {
    const margin = (p.purchasePrice && p.retailPrice)
      ? Math.round((1 - p.purchasePrice / p.retailPrice) * 100) + '%'
      : '-';
    md += `| ${p.id || ''} | ${(p.name || '').slice(0, 30)} | ${p.brand || ''} | ${p.majorCategory || ''} | ${p.category || ''} | ${p.purchasePrice || ''} | ${p.retailPrice || ''} | ${margin} | ${(p.weight || p.spec || '').slice(0, 15)} | ${(p.scene || '').slice(0, 20)} | ${p.priceRange || ''} |\n`;
  });

  md += '\n## 输出要求\n';
  md += '将选品结果写入 **selection-result.json**，格式如下：\n\n';
  md += '```json\n';
  md += JSON.stringify(getResultTemplate(), null, 2);
  md += '\n```\n\n';
  md += '**约束**：productId 必须来自上表中的 ID 列。每件产品必须填写 reason 字段。';

  return md;
}

function getResultTemplate() {
  return {
    generatedAt: new Date().toISOString(),
    mode: currentMode,
    proposals: [{
      id: "A",
      name: "方案名称",
      summary: "一句话描述方案定位",
      targetPersona: "适合什么样的客户",
      products: [{
        productId: "必填，必须在候选表中",
        productName: "...",
        brand: "...",
        majorCategory: "...",
        category: "...",
        supplyPrice: 0,
        retailPrice: 0,
        margin: 0,
        reason: "为什么选这款产品"
      }],
      totals: { productCount: 0, totalCost: 0, totalRetail: 0, avgMargin: 0 },
      categoryBreakdown: { "大类名": { count: 0, cost: 0, ratio: 0 } }
    }],
    globalNotes: "方案间差异说明"
  };
}
```

- [ ] **Step 2: 实现文件写入（File System Access API + 降级）**

```javascript
async function writePromptFile() {
  const md = buildPromptMarkdown();
  if (!md) return;

  // 尝试 File System Access API
  if ('showSaveFilePicker' in window) {
    try {
      const handle = await window.showSaveFilePicker({
        suggestedName: promptFilePath,
        types: [{ description: 'Markdown', accept: { 'text/markdown': ['.md'] } }]
      });
      const writable = await handle.createWritable();
      await writable.write(md);
      await writable.close();
      showToast(`Prompt 已写入`, 'success');
      return;
    } catch (e) {
      if (e.name === 'AbortError') return; // user cancelled
    }
  }

  // 降级：下载文件
  const blob = new Blob([md], { type: 'text/markdown' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = promptFilePath; a.click();
  URL.revokeObjectURL(url);
  showToast('已下载 prompt 文件（浏览器不支持直接写入）', 'success');
}
```

- [ ] **Step 3: 实现剪贴板复制**

```javascript
async function copyPromptToClipboard() {
  const md = buildPromptMarkdown();
  if (!md) return;
  try {
    await navigator.clipboard.writeText(md);
    showToast('Prompt 已复制到剪贴板', 'success');
  } catch (e) {
    // 降级
    const textarea = document.createElement('textarea');
    textarea.value = md; textarea.style.position = 'fixed'; textarea.style.opacity = '0';
    document.body.appendChild(textarea); textarea.select();
    document.execCommand('copy'); document.body.removeChild(textarea);
    showToast('Prompt 已复制到剪贴板', 'success');
  }
}
```

- [ ] **Step 4: 绑定按钮事件**

在 `init()` 中添加：

```javascript
document.getElementById('btnGenerate').addEventListener('click', writePromptFile);
document.getElementById('btnCopyPrompt').addEventListener('click', copyPromptToClipboard);
```

- [ ] **Step 5: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: Prompt 生成 + 文件写入 + 剪贴板复制"
```

---

### Task 5: 结果加载 + 解析 + 校验

**Files:**
- Modify: `claude-selection-workbench.html` (load result, parse, validate)

- [ ] **Step 1: 实现结果加载和解析**

```javascript
async function loadResultFile() {
  if ('showOpenFilePicker' in window) {
    try {
      const [handle] = await window.showOpenFilePicker({
        types: [{ description: 'JSON', accept: { 'application/json': ['.json'] } }]
      });
      const file = await handle.getFile();
      const text = await file.text();
      parseAndDisplay(text);
      return;
    } catch (e) {
      if (e.name === 'AbortError') return;
    }
  }
  // 降级：file input
  const input = document.createElement('input');
  input.type = 'file'; input.accept = '.json';
  input.onchange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const text = await file.text();
    parseAndDisplay(text);
  };
  input.click();
}

async function pasteResult() {
  try {
    const text = await navigator.clipboard.readText();
    parseAndDisplay(text);
  } catch (e) {
    // 降级：显示输入框
    const textarea = document.createElement('textarea');
    textarea.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);width:80vw;height:40vh;z-index:999;';
    textarea.placeholder = '请粘贴结果 JSON...';
    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:998;';
    const btn = document.createElement('button');
    btn.textContent = '解析'; btn.style.cssText = 'position:fixed;top:calc(50%+22vh);left:50%;transform:translateX(-50%);z-index:999;';
    btn.onclick = () => {
      parseAndDisplay(textarea.value);
      document.body.removeChild(overlay);
      document.body.removeChild(textarea);
      document.body.removeChild(btn);
    };
    document.body.appendChild(overlay);
    document.body.appendChild(textarea);
    document.body.appendChild(btn);
  }
}

function parseAndDisplay(jsonText) {
  try {
    const data = JSON.parse(jsonText);
    const errors = validateResult(data);
    if (errors.length > 0) {
      showToast(`校验警告: ${errors.join('; ')}`, 'error');
    }
    selectionResult = data;
    renderResults(data);
    document.getElementById('btnExport').disabled = false;
    showToast(`已加载 ${data.proposals?.length || 0} 套方案`, 'success');
  } catch (e) {
    showToast('JSON 解析失败: ' + e.message, 'error');
    // 显示原始文本供调试
    document.getElementById('resultsArea').innerHTML =
      `<div class="panel-box">
        <div style="color:var(--accent);margin-bottom:8px;">JSON 解析失败</div>
        <pre style="font-size:10px;color:var(--muted);white-space:pre-wrap;max-height:200px;overflow-y:auto;">${escapeHtml(jsonText.slice(0, 2000))}</pre>
        <textarea id="fixJsonInput" rows="6" style="margin-top:8px;font-size:10px;">${escapeHtml(jsonText)}</textarea>
        <button onclick="parseAndDisplay(document.getElementById('fixJsonInput').value)" style="margin-top:4px;">重新解析</button>
      </div>`;
  }
}

// 构建 productId → product 索引
function buildProductIndex() {
  const idx = {};
  allProducts.forEach(p => { idx[p.id] = p; });
  return idx;
}

function validateResult(data) {
  const errors = [];
  if (!data.proposals || !Array.isArray(data.proposals)) {
    errors.push('缺少 proposals 数组');
    return errors;
  }
  const productIdx = buildProductIndex();

  data.proposals.forEach((proposal, i) => {
    if (!proposal.products || !Array.isArray(proposal.products)) {
      errors.push(`方案 ${proposal.id || i}: 缺少 products 数组`);
      return;
    }
    proposal.products.forEach((p, j) => {
      if (!p.productId) {
        errors.push(`方案 ${proposal.id || i} 产品 ${j}: 缺少 productId`);
      } else if (!productIdx[p.productId]) {
        p._notFound = true;
      }
      if (!p.reason) {
        errors.push(`方案 ${proposal.id || i} 产品 ${j}: 缺少 reason`);
      }
    });
  });
  return errors;
}
```

- [ ] **Step 2: 绑定按钮**

```javascript
document.getElementById('btnLoadResult').addEventListener('click', loadResultFile);
document.getElementById('btnPasteResult').addEventListener('click', pasteResult);
```

- [ ] **Step 3: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: 结果加载 + JSON 解析校验 + 容错处理"
```

---

### Task 6: 结果可视化（卡片 + 详情表格 + 方案对比）

**Files:**
- Modify: `claude-selection-workbench.html` (renderResults + related)

- [ ] **Step 1: 实现结果渲染**

```javascript
let selectedProposalIds = new Set(); // for comparison

function renderResults(data) {
  const container = document.getElementById('resultsArea');
  if (!data.proposals || data.proposals.length === 0) {
    container.innerHTML = '<div style="color:var(--muted);text-align:center;padding:20px;">无方案数据</div>';
    return;
  }

  const productIdx = buildProductIndex();

  // Comparison toggle bar
  let html = '<div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">';
  html += `<span style="font-size:10px;color:var(--muted);">${data.proposals.length} 套方案</span>`;
  if (data.globalNotes) {
    html += `<span style="font-size:10px;color:var(--muted);">· ${escapeHtml(data.globalNotes.slice(0, 80))}</span>`;
  }
  html += '<span style="flex:1;"></span>';
  html += `<button class="small" onclick="toggleCompareView()">📊 对比方案</button>`;
  html += '</div>';

  // Proposal cards
  html += '<div class="cards-row">';
  data.proposals.forEach((proposal, idx) => {
    const totals = proposal.totals || {};
    const isSelected = selectedProposalIds.has(proposal.id);
    html += `<div class="proposal-card${isSelected ? ' selected' : ''}"
      data-proposal-id="${escapeHtml(proposal.id)}"
      onclick="toggleProposalDetail('${escapeHtml(proposal.id)}')">`;
    html += `<div class="name">方案 ${proposal.id} · ${escapeHtml(proposal.name || '')}</div>`;
    if (proposal.summary) {
      html += `<div style="font-size:10px;color:var(--muted);margin-top:2px;">${escapeHtml(proposal.summary.slice(0, 60))}</div>`;
    }
    html += `<div class="stats">`;
    html += `${totals.productCount || 0}件 · ¥${(totals.totalCost || 0).toFixed(1)}/人 · 毛利${(totals.avgMargin || 0).toFixed(0)}%`;
    html += '</div>';
    if (proposal.products) {
      html += `<div class="preview">${proposal.products.slice(0, 4).map(p => escapeHtml(p.productName || '').slice(0, 12)).join('、')}...</div>`;
    }
    html += '</div>';
  });
  html += '</div>';

  // Detail panel (for clicked proposal)
  html += '<div id="proposalDetail" class="panel-box"></div>';

  // Compare view (hidden by default)
  html += '<div id="compareView" class="panel-box hidden"></div>';

  container.innerHTML = html;
}

function toggleProposalDetail(proposalId) {
  if (!selectionResult) return;
  const proposal = selectionResult.proposals.find(p => p.id === proposalId);
  if (!proposal) return;

  const detailPanel = document.getElementById('proposalDetail');
  if (detailPanel.dataset.activeId === proposalId) {
    detailPanel.innerHTML = '';
    detailPanel.dataset.activeId = '';
    return;
  }

  detailPanel.dataset.activeId = proposalId;
  const totals = proposal.totals || {};
  const catBreakdown = proposal.categoryBreakdown || {};

  let html = `<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
    <strong>📋 方案 ${proposal.id} · ${escapeHtml(proposal.name || '')}</strong>
    <span style="font-size:10px;color:var(--muted);">${escapeHtml(proposal.targetPersona || '')}</span>
  </div>`;

  // Summary stats
  html += '<div style="display:flex;gap:16px;margin-bottom:10px;font-size:11px;">';
  html += `<span>产品数: <strong>${totals.productCount || 0}</strong></span>`;
  html += `<span>总成本: <strong>¥${(totals.totalCost || 0).toFixed(1)}/人</strong></span>`;
  html += `<span>零售总额: <strong>¥${(totals.totalRetail || 0).toFixed(1)}/人</strong></span>`;
  html += `<span>平均毛利率: <strong style="color:var(--green);">${(totals.avgMargin || 0).toFixed(0)}%</strong></span>`;
  html += '</div>';

  // Category breakdown
  if (Object.keys(catBreakdown).length > 0) {
    html += '<div style="display:flex;gap:8px;margin-bottom:10px;flex-wrap:wrap;">';
    for (const [cat, info] of Object.entries(catBreakdown)) {
      html += `<span class="tag" style="font-size:9px;">${escapeHtml(cat)}: ${info.count}件 · ${(info.ratio || 0).toFixed(0)}%</span>`;
    }
    html += '</div>';
  }

  // Product table
  html += '<table class="detail-table"><thead><tr>';
  html += '<th>产品名称</th><th>品牌</th><th>品类</th><th style="text-align:right;">供货价</th>';
  html += '<th style="text-align:right;">零售价</th><th style="text-align:right;">毛利率</th><th>选品理由</th>';
  html += '</tr></thead><tbody>';

  (proposal.products || []).forEach(p => {
    const warnClass = p._notFound ? ' warning' : '';
    const margin = (p.margin != null) ? p.margin + '%' :
      (p.supplyPrice && p.retailPrice) ? Math.round((1 - p.supplyPrice / p.retailPrice) * 100) + '%' : '-';
    html += `<tr class="${warnClass}">`;
    html += `<td>${escapeHtml(p.productName || '')}${p._notFound ? ' ⚠已下架' : ''}</td>`;
    html += `<td>${escapeHtml(p.brand || '')}</td>`;
    html += `<td>${escapeHtml(p.category || '')}</td>`;
    html += `<td style="text-align:right;">${p.supplyPrice != null ? '¥' + p.supplyPrice : '-'}</td>`;
    html += `<td style="text-align:right;">${p.retailPrice != null ? '¥' + p.retailPrice : '-'}</td>`;
    html += `<td style="text-align:right;color:var(--green);">${margin}</td>`;
    html += `<td style="font-size:10px;color:var(--muted);max-width:200px;">${escapeHtml(p.reason || '')}</td>`;
    html += '</tr>';
  });

  html += '</tbody></table>';
  detailPanel.innerHTML = html;
}

function toggleCompareView() {
  const panel = document.getElementById('compareView');
  if (!panel.classList.contains('hidden')) {
    panel.classList.add('hidden');
    return;
  }
  panel.classList.remove('hidden');

  if (!selectionResult || !selectionResult.proposals) return;
  const proposals = selectionResult.proposals;

  let html = '<strong>📊 方案对比</strong>';
  html += '<div style="overflow-x:auto;margin-top:8px;">';
  html += '<table class="detail-table"><thead><tr>';
  html += '<th>维度</th>';
  proposals.forEach(p => { html += `<th>方案 ${escapeHtml(p.id)}</th>`; });
  html += '</tr></thead><tbody>';

  const rows = [
    ['方案名称', p => escapeHtml(p.name || '')],
    ['定位', p => escapeHtml(p.summary || '')],
    ['产品数', p => (p.totals || {}).productCount || 0],
    ['人均成本', p => '¥' + ((p.totals || {}).totalCost || 0).toFixed(1)],
    ['平均毛利率', p => ((p.totals || {}).avgMargin || 0).toFixed(0) + '%'],
    ['适合客户', p => escapeHtml(p.targetPersona || '')],
    ['top 3 品类', p => {
      const cats = p.categoryBreakdown || {};
      return Object.entries(cats).sort((a,b) => b[1].ratio - a[1].ratio)
        .slice(0,3).map(([c,info]) => `${c}(${info.count})`).join(', ');
    }]
  ];

  rows.forEach(([label, fn]) => {
    html += '<tr>';
    html += `<td style="color:var(--muted);">${label}</td>`;
    proposals.forEach(p => { html += `<td>${fn(p)}</td>`; });
    html += '</tr>';
  });

  html += '</tbody></table></div>';
  panel.innerHTML = html;
}
```

- [ ] **Step 2: 在浏览器中测试结果展示**

用测试数据验证：

```javascript
// 在 console 中
parseAndDisplay(JSON.stringify({
  generatedAt: new Date().toISOString(),
  mode: 'full',
  proposals: [
    {
      id: 'A', name: '新潮实用', summary: '聚焦年轻员工', targetPersona: '年轻互联网公司',
      products: [
        { productId: 1, productName: '三只松鼠坚果礼盒', brand: '三只松鼠', majorCategory: '食品饮料', category: '坚果炒货', supplyPrice: 55, retailPrice: 78, margin: 29, reason: '年轻群体认知度高' }
      ],
      totals: { productCount: 1, totalCost: 55, totalRetail: 78, avgMargin: 29 },
      categoryBreakdown: { '食品饮料': { count: 1, cost: 55, ratio: 100 } }
    }
  ],
  globalNotes: '测试'
}));
```

确认：卡片显示、点击展开详情、产品表格、对比视图均正常。

- [ ] **Step 3: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: 结果可视化（卡片/详情表格/方案对比）"
```

---

### Task 7: Toast 通知 + 导出到现有系统

**Files:**
- Modify: `claude-selection-workbench.html` (toast, export)

- [ ] **Step 1: 实现 Toast 通知**

```javascript
function showToast(message, type) {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(() => { toast.remove(); }, 3000);
}
```

- [ ] **Step 2: 实现导出到现有系统**

```javascript
async function exportToExistingSystem() {
  if (!selectionResult) { showToast('无结果可导出', 'error'); return; }
  try {
    // 写入 IndexedDB proposals 表
    const tx = db.transaction('proposals', 'readwrite');
    const store = tx.objectStore('proposals');

    for (const proposal of selectionResult.proposals) {
      const record = {
        id: `cc-${Date.now()}-${proposal.id}`,
        name: proposal.name || '',
        summary: proposal.summary || '',
        targetPersona: proposal.targetPersona || '',
        products: proposal.products || [],
        totals: proposal.totals || {},
        categoryBreakdown: proposal.categoryBreakdown || {},
        source: 'claude-code-workbench',
        createdAt: new Date().toISOString()
      };
      await new Promise((resolve, reject) => {
        const req = store.put(record);
        req.onsuccess = resolve;
        req.onerror = reject;
      });
    }

    showToast(`已导出 ${selectionResult.proposals.length} 套方案到 proposals 表`, 'success');
  } catch (e) {
    showToast('导出失败: ' + e.message, 'error');
  }
}

document.getElementById('btnExport').addEventListener('click', exportToExistingSystem);
```

- [ ] **Step 3: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "feat: Toast 通知 + 导出到现有系统 IndexedDB"
```

---

### Task 8: watch-selection.sh 监听脚本

**Files:**
- Create: `watch-selection.sh`

- [ ] **Step 1: 创建监听脚本**

```bash
#!/bin/bash
# watch-selection.sh — 监听 prompt 文件，自动调用 Claude Code 选品
# 用法: bash watch-selection.sh [prompt文件] [result文件]
# 默认: selection-prompt.md → selection-result.json

PROMPT_FILE="${1:-selection-prompt.md}"
RESULT_FILE="${2:-selection-result.json}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_PATH="$SCRIPT_DIR/$PROMPT_FILE"
RESULT_PATH="$SCRIPT_DIR/$RESULT_FILE"

echo "=== Claude Code 选品监听器 ==="
echo "监听文件: $PROMPT_PATH"
echo "结果文件: $RESULT_PATH"
echo "按 Ctrl+C 停止"
echo ""

if ! command -v fswatch &>/dev/null && ! command -v inotifywait &>/dev/null; then
  echo "⚠ 未检测到 fswatch 或 inotifywait，使用轮询模式（每2秒检查一次）"
  POLL_MODE=true
else
  POLL_MODE=false
fi

LAST_MOD=0
while true; do
  if [ -f "$PROMPT_PATH" ]; then
    CURRENT_MOD=$(stat -c %Y "$PROMPT_PATH" 2>/dev/null || stat -f %m "$PROMPT_PATH" 2>/dev/null)
    if [ "$CURRENT_MOD" != "$LAST_MOD" ] && [ -s "$PROMPT_PATH" ]; then
      LAST_MOD="$CURRENT_MOD"
      echo ""
      echo ">>> [$(date '+%H:%M:%S')] 检测到 prompt 更新，开始选品..."
      echo ""

      # 调用 Claude Code CLI（非交互模式）
      PROMPT_CONTENT=$(cat "$PROMPT_PATH")
      echo "$PROMPT_CONTENT" | claude --print 2>&1 | tee "$RESULT_PATH.tmp"

      # 尝试从输出中提取 JSON（Claude Code 可能包含额外文本）
      # 提取从 { 到 } 的最大 JSON 块
      if [ -f "$RESULT_PATH.tmp" ]; then
        python3 -c "
import sys, re, json
text = open('$RESULT_PATH.tmp').read()
# 尝试找到最外层的 JSON 对象
match = re.search(r'\{[\s\S]*"proposals"[\s\S]*\}', text)
if match:
    try:
        json.loads(match.group())
        with open('$RESULT_PATH', 'w') as f:
            f.write(match.group())
        print('结果已提取并写入 $RESULT_PATH')
    except:
        # 复制原文
        open('$RESULT_PATH', 'w').write(text)
        print('警告：无法提取有效 JSON，已保存原始输出')
else:
    open('$RESULT_PATH', 'w').write(text)
    print('警告：输出中未找到 JSON，已保存原始输出')
"
        rm -f "$RESULT_PATH.tmp"
      fi

      echo ""
      echo "<<< [$(date '+%H:%M:%S')] 选品完成，结果已写入 $RESULT_PATH"
      echo ""
    fi
  fi

  if [ "$POLL_MODE" = true ]; then
    sleep 2
  else
    # 使用文件监听工具
    if command -v fswatch &>/dev/null; then
      fswatch -1 "$PROMPT_PATH" 2>/dev/null
    elif command -v inotifywait &>/dev/null; then
      inotifywait -e modify,create "$PROMPT_PATH" 2>/dev/null
    fi
  fi
done
```

- [ ] **Step 2: 赋予可执行权限并测试**

```bash
chmod +x watch-selection.sh
```

- [ ] **Step 3: 提交**

```bash
git add watch-selection.sh
git commit -m "feat: 添加文件监听脚本（自动桥接 Claude Code CLI）"
```

---

### Task 9: 整体集成测试 + 边界处理

**Files:**
- Modify: `claude-selection-workbench.html` (final integration fixes)

- [ ] **Step 1: 处理边界情况**

确保以下场景不崩溃：
- 数据库为空（0条商品）→ 显示"无商品数据"
- 筛选后 0 条候选 → 提示"筛选后无候选商品，请放宽条件"
- 方案中 productId 不在库中 → 红色警告标记
- JSON 格式错误 → 显示原始文本 + 手动修复框

在 `applyFilters()` 后检查：

```javascript
if (filteredProducts.length === 0 && allProducts.length > 0) {
  // 在 updateFilteredCount 中已显示
}
```

- [ ] **Step 2: 端到端测试流程**

1. 打开 `claude-selection-workbench.html`
2. 确认商品数量显示正确
3. 勾选大类 → 品类自动联动
4. 输入需求文本 → 参数自动提取
5. 点击"生成 Prompt" → 文件下载/保存成功
6. 查看 prompt 内容完整
7. 粘贴测试结果 JSON → 卡片 + 详情渲染正确
8. 点击"导出到现有系统" → IndexedDB proposals 表有数据

- [ ] **Step 3: 提交**

```bash
git add claude-selection-workbench.html
git commit -m "fix: 边界处理 + 整体集成验证"
```

---

## 计划总结

| Task | 内容 | 预计行数 |
|------|------|---------|
| 1 | HTML 骨架 + DB 连接 | ~150 |
| 2 | 动态预筛引擎 | ~200 |
| 3 | 三种模式 + 参数配置 | ~150 |
| 4 | Prompt 生成 + 文件写入 | ~150 |
| 5 | 结果加载 + 校验 | ~120 |
| 6 | 结果可视化 | ~200 |
| 7 | Toast + 导出 | ~50 |
| 8 | watch-selection.sh | ~70 |
| 9 | 集成测试 + 边界 | ~30 |
| **合计** | | **~1120** |

所有代码在一个文件 `claude-selection-workbench.html` 中完成。
