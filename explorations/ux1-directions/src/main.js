const state = { scheme: 'a', task: 'favorites', theme: 'light', accent: 'blue', density: 'comfortable', detailLayout: 'info', startup: 'restore', favorite: false, shelf: 'normal', split: true, preview: false, previewIndex: 0, previewSection: 'overview', clickBehavior: 'detail', readingIndex: 0, readerMode: 'normal', narrow: false, largeText: false, reducedMotion: false, sidebarOverlay: false, lastSelected: 0, activeTab: 'search', closeBehavior: 'recent', tabRecency: ['search'], closedTabs: ['author'], tabOrder: ['search', 'detail', 'author'], addedTabs: [], tabSerial: 0, selectedResults: [], resultStatus: 'ready', tabHistory: {}, dragging: null, tabMenu: false, chrome: true, chapters: false, selected: false, sidebar: true, notice: '' };

const schemes = {
  a: { name: 'A · 书架型', feel: '像走进整理好的书架：左侧直接看到收藏分类，中间先看封面与作者。标签保存工作现场，预览用于临时判断，不再需要分屏。', cost: '标签过多仍需要溢出管理；拖放是高效捷径，但必须同时提供按钮、右键与键盘入口。' },
  b: { name: 'B · 工作台型', feel: '像 IDE 或文件管理器：目录、内容、筛选与详情同时可见。两个来源可以各自保留标签和滚动位置，适合长时间对照、筛选和批量整理。', cost: '面板与边界更多，视觉上最容易再次显得“硬”；窄窗口必须严格规定哪些面板先收起。' },
  c: { name: 'C · 混合型', feel: '平时只保留当前位置、筛选摘要和内容；选中作品或按空格时出现辅助面板。需要比较时再把标签拖成分屏，关闭后回到普通浏览。', cost: '需要更严谨地定义“何时展开、何时收回”以及焦点归属，否则临时面板会变成新的弹窗混乱。' }
};
const tasks = { favorites: '收藏首页', shelf: '作者 shelf 三态', tabs: '多标签与拖放', preview: '快速预览', reader: '阅读器 chrome' };
const covers = ['oklch(0.68 0.13 25)','oklch(0.61 0.12 155)','oklch(0.58 0.13 255)','oklch(0.67 0.13 75)','oklch(0.61 0.11 320)','oklch(0.63 0.1 200)','oklch(0.66 0.12 45)','oklch(0.59 0.1 135)'];
const titles = ['星海邮差','白昼梦','远山来信','环形宇宙','夏日档案','青之轨迹','夜航西飞','无用侦探'];
function displayTitle(i) { return state.scheme === 'a' && (state.narrow || state.largeText) && i === 0 ? '星海邮差：跨越漫长星海、穿越无尽冬夜的来信与最终归途' : titles[i % titles.length]; }

function comic(i, detailed = false) {
  const title = displayTitle(i);
  return `<div class="comic ${state.selected && i === 0 ? 'selected-card' : ''}"><div class="cover" style="--cover:${covers[i % covers.length]}"></div><div class="comic-title" title="${title}">${title}</div><div class="meta">${i % 3 === 0 ? '<span class="update-dot"></span>更新 2 章 · ' : ''}${detailed ? `来源 ${String.fromCharCode(65 + i % 3)} · 作者 ${i % 2 ? '青木' : '林原'}` : `第 ${12 + i} 话`}</div></div>`;
}
function rail() { return `<div class="rail"><span class="rail-icon">⌂</span><span class="rail-icon active">▤</span><span class="rail-icon">◎</span><span class="rail-icon">▦</span></div>`; }
function labelNav() { return `<div class="label-nav"><div class="brand">Venera</div><div class="sidebar-search"><span>⌕</span><span>搜索漫画…</span><kbd>⌘K</kbd></div><div class="nav-row">首页</div><div class="nav-row active">收藏</div><div class="nav-group">本地</div><div class="nav-row">全部漫画 <small>200</small></div><div class="nav-row active">正在追更</div><div class="nav-row">稍后阅读</div><div class="nav-group">系列</div><div class="nav-row">跨来源系列</div></div>`; }
function folders() { return `<div class="folders"><div class="folder-head">收藏</div><div class="folder-row">⌄ 本地</div><div class="folder-row active">　全部漫画　200</div><div class="folder-row active">　正在追更　48</div><div class="folder-row">　稍后阅读　16</div><div class="folder-row">› 系列</div><div class="folder-row">› 网络</div></div>`; }
function inspector(kind = 'filter') {
  if (kind === 'author') return `<aside class="inspector"><h3>林原 · 作者</h3><div class="inspect-section"><div class="inspect-row"><span>本栏漫画</span><b>12 部</b></div><div class="inspect-row"><span>排序</span><b>栏内手动</b></div></div><div class="inspect-section"><b>平台名称</b><div class="inspect-row"><span>来源 A</span><b>林原</b></div><div class="inspect-row"><span>来源 B</span><b>Lin Yuan</b></div></div><div class="inspect-section"><span class="chip active">点击名称可单源搜索</span></div></aside>`;
  return `<aside class="inspector"><h3>筛选与整理</h3><div class="inspect-section"><div class="inspect-row"><span>排序</span><b>作者分栏</b></div><div class="inspect-row"><span>阅读状态</span><b>全部</b></div></div><div class="inspect-section"><b>作者</b><p class="meta">林原　青木　+6</p></div><div class="inspect-section"><b>标签</b><p class="meta">科幻　悬疑　+12</p></div><div class="inspect-section"><span class="chip active">已筛选：追更中</span></div></aside>`;
}
function pageHead(title = '正在追更') { return `<div class="page-head"><div><h2>${title}</h2><p>48 部作品 · 6 部有更新 · 作者分栏</p></div><div class="tools"><span class="tool">筛选摘要</span><span class="tool">画廊 ▾</span><span class="tool">⋯</span></div></div>`; }
function selectionBar() { return state.selected ? `<div class="filter-summary"><span class="chip active">已选择 1 部</span><span class="chip">加入系列</span><span class="chip">移动</span><span class="chip">下载</span><span class="chip">Esc 取消</span></div>` : `<div class="filter-summary"><span class="chip active">追更中</span><span class="chip">全部来源 ▾</span><span class="chip">阅读状态：全部</span><span class="chip">作者分栏 · 每栏独立排序</span></div>`; }
function shelf(mode = state.shelf, count = 5) {
  const content = mode === 'collapsed' ? `<div class="shelf-row">${Array.from({length: count}, (_, i) => comic(i, true)).join('')}</div>` : `<div class="covers">${Array.from({length: count}, (_, i) => comic(i, true)).join('')}</div>${mode === 'expanded' ? '<div class="platform-panel"><p>平台名称 · 展开不发起网络请求</p><span class="chip">来源 A：林原</span> <span class="chip">来源 B：Lin Yuan</span> <span class="chip">来源 C：林 原</span></div>' : ''}`;
  return `<section class="shelf ${mode}"><div class="shelf-head"><strong>林原</strong><span>12 部 · 栏内手动排序</span><span class="chevron">${mode === 'collapsed' ? '›' : mode === 'expanded' ? '名称已展开 ⌄' : '⌄'}</span></div>${content}</section>`;
}
function favorites() {
  if (state.scheme === 'a') return notionShell(`<main class="content">${pageHead()}${selectionBar()}${shelf('collapsed')}<div class="shelf-head"><strong>青木</strong><span>8 部</span><span class="chevron">⌄</span></div><div class="covers large">${[0,1,2,3,4,5].map(i => comic(i)).join('')}</div></main>`);
  if (state.scheme === 'b') return `<div class="app-window">${windowTitle()}${docTabs()}<div class="app-body" style="grid-template-columns:42px 130px minmax(0,1fr) 170px">${rail()}${folders()}<main class="content compact">${pageHead()}${selectionBar()}<div class="covers dense">${[0,1,2,3,4,5,6,7,8,9].map(i => comic(i, true)).join('')}</div></main>${inspector()}</div></div>`;
  return `<div class="app-window">${windowTitle()}<div class="app-body" style="grid-template-columns:42px 132px minmax(0,1fr)">${rail()}${folders()}<main class="content">${pageHead()}${selectionBar()}${shelf('collapsed')}<div class="shelf-head"><strong>青木</strong><span>8 部</span><span class="chevron">⌄</span></div><div class="covers">${[0,1,2,3,4,5,6,7].map(i => comic(i, true)).join('')}</div></main></div></div>`;
}
function shelfView() {
  if (state.scheme === 'a') return notionShell(`<main class="content">${pageHead('作者分栏')}${shelf()}${shelf('collapsed')}</main>`);
  const extra = state.scheme === 'b' ? `<div class="app-body" style="grid-template-columns:42px 130px minmax(0,1fr) 170px">${rail()}${folders()}<main class="content compact">${pageHead('作者分栏')}${shelf()}${shelf('collapsed')}</main>${inspector('author')}</div>` : `<div class="app-body" style="grid-template-columns:42px 132px minmax(0,1fr)">${rail()}${folders()}<main class="content">${pageHead('作者分栏')}${shelf()}${shelf('collapsed')}</main></div>`;
  return `<div class="app-window">${windowTitle()}${extra}</div>`;
}
function windowTitle() { return `<div class="window-title"><span class="dots">●●●</span><span>收藏</span><span class="title-search">搜索当前页面…</span><span>☷</span></div>`; }
function windowControls() {
  const visible = state.narrow ? state.sidebarOverlay : state.sidebar;
  const label = state.narrow ? (visible ? '关闭侧栏浮层' : '打开侧栏浮层') : (visible ? '收起侧栏' : '展开侧栏');
  return `<span class="window-controls"><span class="dots">●●●</span><button class="shell-toggle" data-action="sidebar" aria-label="${label}" title="${label}">▥</button></span>`;
}
function workspaceTop(mode = 'page') {
  const canGoBack = state.scheme === 'a' && !!state.tabHistory[state.activeTab];
  return `<div class="workspace-top">${state.sidebar && !state.narrow ? '' : windowControls()}<span class="history-arrows"><button data-action="historyBack" aria-label="返回原搜索页" title="${canGoBack ? '返回原搜索页 · Alt+←' : '没有可返回的页面'}" ${canGoBack ? '' : 'disabled'}>‹</button><button aria-label="前进" title="没有可前进的页面" disabled>›</button></span>${mode === 'tabs' ? aTabStrip() : '<span class="breadcrumb">收藏　/　正在追更</span><span class="top-spacer"></span><span class="tool">页面操作</span><span class="tool">⋯</span>'}</div>`;
}
function notionShell(body, overlay = '', topMode = 'page') {
  const narrow = state.scheme === 'a' && state.narrow;
  const showSidebar = narrow ? state.sidebarOverlay : state.sidebar;
  const sidebar = showSidebar ? `<aside class="notion-sidebar ${narrow ? 'sidebar-overlay' : ''}"><div class="sidebar-title">${windowControls()}<span class="top-spacer"></span><span class="tool">＋</span></div>${labelNav()}</aside>` : '';
  const scrim = narrow && state.sidebarOverlay ? '<button class="sidebar-scrim" data-action="sidebarOverlayClose" aria-label="点击侧栏外部关闭"></button>' : '';
  return `<div class="app-window" data-layout="${narrow ? 'narrow' : 'wide'}"><div class="notion-shell ${!narrow && state.sidebar ? '' : 'collapsed'}">${scrim}${sidebar}<section class="notion-workspace">${workspaceTop(topMode)}${body}</section></div>${overlay}</div>`;
}
function docTabs(second = false) { return `<div class="doc-tabs"><div class="doc-tab active">${second ? '来源 B · 星海邮差' : '来源 A · 搜索结果'} <small>×</small></div><div class="doc-tab">${second ? '作者：林原' : '来源 B · 搜索结果'} <small>×</small></div><div class="doc-tab">＋</div></div>`; }
function aTabs() {
  const base = [{id:'search',label:'来源 A · 搜索',state:'滚动 320px · 筛选保留'},{id:'detail',label:`${displayTitle(0)} · 详情`,state:'第 18 话 · 章节展开'},{id:'author',label:'作者 · 林原',state:'平台名称编辑状态保留'}];
  return state.tabOrder.map(id => base.find(tab => tab.id === id) || state.addedTabs.find(tab => tab.id === id)).filter(tab => tab && !state.closedTabs.includes(tab.id));
}
function aTabStrip() {
  const tabs = aTabs();
  const overflow = tabs.length > 4;
  const menu = state.tabMenu ? `<div class="tab-menu-popover"><div class="tab-menu-title">全部标签 · ${tabs.length}</div>${tabs.map(tab => `<button class="tab-menu-item ${state.activeTab === tab.id ? 'active' : ''}" data-action="tab:${tab.id}"><span title="${tab.label}">${tab.label}</span><small>${state.activeTab === tab.id ? '当前' : tab.loaded === false ? '待激活 · 首次打开时加载' : tab.state}</small></button>`).join('')}<div class="tab-menu-resource">后台详情首次激活时加载<br>阅读器后台休眠，保留章节与页码</div></div>` : '';
  return `<div class="doc-tabs notion-tabs" data-tab-dropzone aria-label="漫画标签栏，可用触摸板横向滚动或将搜索结果拖到这里"><div class="tab-scroll-region">${tabs.map(tab => `<div class="doc-tab ${state.activeTab === tab.id ? 'active' : ''}" data-tab-id="${tab.id}" title="${tab.label}\n${tab.state}"><button class="tab-main" data-action="tab:${tab.id}">${tab.label}</button><button class="tab-close" data-action="close:${tab.id}" aria-label="关闭 ${tab.label}">×</button></div>`).join('')}</div>${overflow ? `<button class="tab-overview" data-action="tabMenu" aria-expanded="${state.tabMenu}" title="查看全部标签">全部 ${tabs.length} ▾</button>` : ''}<button class="tab-add" data-action="addTab" aria-label="新建标签" title="新建或恢复标签 · Ctrl/Cmd+T">＋</button>${menu}</div>`;
}
function aResultTiles() {
  return `<div class="result-tiles">${[0,1,2,3].map(i => { const title = displayTitle(i); return `<div class="comic-result ${i === state.previewIndex ? 'active' : ''} ${state.selectedResults.includes(i) ? 'checked' : ''}" draggable="true" data-comic-index="${i}" title="点击打开；悬停按 Space 预览；右键在后台新标签打开"><button class="tile-main" data-action="openResult:${i}" aria-label="打开 ${title}"><div class="cover" style="--cover:${covers[i]}"></div><div class="tile-copy"><b title="${title}">${title}</b><span class="meta">${i % 2 ? '星海文库' : '林原'} · 更新至 ${20 + i} 话</span></div></button><button class="result-check" data-action="selectResult:${i}" aria-label="${state.selectedResults.includes(i) ? '取消选择' : '选择'} ${title}" aria-pressed="${state.selectedResults.includes(i)}">${state.selectedResults.includes(i) ? '✓' : ''}</button></div>`; }).join('')}</div>`;
}
function aResultContent() {
  const head = `<div class="pane-title"><strong>“星海邮差”</strong><span>${state.resultStatus === 'loading' ? '正在从 2 个来源搜索…' : state.resultStatus === 'empty' ? '0 个结果 · 关键词与筛选已保留' : '点击打开 · 悬停按 Space 预览 · 右上角勾选后可拖到标签栏'}</span></div>`;
  if (state.resultStatus === 'loading') return `${head}<div class="result-tiles result-skeleton" aria-busy="true" aria-label="正在加载搜索结果">${Array.from({length:4}, () => '<div class="skeleton-card"><div class="skeleton-cover"></div><span></span><span></span></div>').join('')}</div>`;
  if (state.resultStatus === 'empty') return `${head}<div class="empty-state"><strong>没有找到匹配的漫画</strong><p>当前范围：来源 A · 追更中。可以调整条件，不需要重新输入关键词。</p><div><button class="tool" data-action="resultStatus:ready">清空筛选</button><button class="tool primary" data-action="resultStatus:ready">尝试全部来源</button></div></div>`;
  const status = state.resultStatus === 'refreshing' ? '<div class="result-status refreshing" role="status"><span class="status-spinner"></span><span>正在更新… 当前结果仍可打开</span></div>' : state.resultStatus === 'error' ? '<div class="result-status error" role="alert"><span>来源 B 更新失败 · 显示此前结果，可能不是最新</span><button data-action="resultStatus:refreshing">重试</button></div>' : '';
  return `<div class="drop-feedback" aria-live="polite"></div>${head}${status}${aResultTiles()}`;
}
function resultContent(second = false) {
  if (state.scheme === 'a') return aResultContent();
  return `<div class="pane-title"><strong>“星海邮差”</strong><span>${second ? '来源 B · 12 个结果' : '来源 A · 24 个结果'} · 搜索选项与滚动位置已保留</span></div><div class="result-list">${[0,1,2,3].map(i => `<div class="result ${i === state.previewIndex ? 'active' : ''}"><div class="thumb" style="--cover:${covers[(i + (second ? 2 : 0)) % covers.length]}"></div><div><b>${titles[i]}</b><div class="meta">${i % 2 ? '星海文库' : '林原'} · 更新至 ${20 + i} 话</div><div class="meta">匹配标题与作者</div></div></div>`).join('')}</div>`;
}
function resultPane(second = false, showTabs = true) { return `<section class="pane">${showTabs ? docTabs(second) : ''}${resultContent(second)}</section>`; }
function detailContent(index = 0) {
  const reading = state.detailLayout === 'reading';
  const metadata = '<p>作者：林原<br>来源：来源 B<br>分类：科幻 / 冒险<br>状态：连载中</p>';
  const actions = `<div class="detail-actions"><span class="tool primary">继续阅读 · 第 18 话</span><button class="tool" data-action="favorite" aria-pressed="${state.favorite}">${state.favorite ? '★ 已收藏' : '☆ 收藏'}</button></div>`;
  const chapters = '<h3 class="detail-section-title">最近章节</h3><div class="chapter"><span>第 20 话 · 返航</span><span>3 天前</span></div><div class="chapter"><span>第 19 话 · 群星</span><span>已读</span></div><div class="chapter"><span>第 18 话 · 信标</span><span>当前</span></div>';
  const hero = `<div class="detail-hero"><div class="detail-cover" style="--cover:${covers[index]}"></div><div><h2>${titles[index]}</h2>${metadata}${actions}</div></div>`;
  const synopsis = '<p class="detail-synopsis">一封没有署名的来信，让星际邮差踏上跨越星海的返航之旅。沿途的讯号、旧友与未知航线，逐渐指向信标的真正来源。</p>';
  if (!reading) return `<div class="detail detail-info">${hero}<h3 class="detail-section-title">作品简介</h3>${synopsis}${chapters}</div>`;
  return `<div class="detail detail-reading">${hero}<details class="detail-metadata"><summary>作品详情与来源</summary>${metadata}${synopsis}</details>${chapters}</div>`;
}
function detailPane(showTabs = true, index = 0) { return `<section class="pane">${showTabs ? docTabs(true) : ''}${detailContent(index)}</section>`; }
function authorPane() { return `<section class="pane"><div class="detail"><h2>林原</h2><p>创作者平台名称 · 编辑状态保留在此标签</p><div class="chapter"><span>来源 A</span><span>林原</span></div><div class="chapter"><span>来源 B</span><span>Lin Yuan</span></div><div class="chapter"><span>来源 C</span><span>林 原</span></div></div></section>`; }
function emptyPane() { return `<section class="pane"><div class="detail"><h2>新标签</h2><p>从左侧全局搜索开始，或返回收藏继续浏览。</p><span class="tool primary">搜索漫画</span></div></section>`; }
function aCurrentPane() {
  const added = state.addedTabs.find(tab => tab.id === state.activeTab);
  if (added) return detailPane(false, added.comicIndex);
  return state.activeTab === 'detail' ? detailPane(false) : state.activeTab === 'author' ? authorPane() : state.activeTab === 'search' ? resultPane(false, false) : emptyPane();
}
function tabsView() {
  if (state.scheme === 'a') return notionShell(aCurrentPane(), '', 'tabs');
  const body = state.split ? `<div class="split">${resultPane()}${detailPane()}</div>` : resultPane();
  return `<div class="app-window">${windowTitle()}${body}</div>`;
}
function previewContent() {
  const i = state.previewIndex;
  const section = state.previewSection === 'chapters' ? '<p>第 24 话 · 未读<br>第 23 话 · 已读<br>第 22 话 · 已读</p>' : state.previewSection === 'details' ? '<p class="meta">作者：林原<br>来源：来源 A<br>标签：科幻 / 冒险<br>收藏：正在追更</p>' : '<p class="meta">林原 · 来源 A<br>连载中 · 24 话<br>科幻 / 冒险</p><p>更新至第 24 话</p>';
  return `<div class="preview-grid"><div class="cover" style="--cover:${covers[i]}"></div><div><h3>${titles[i]}</h3>${section}<span class="chip active">Enter 当前标签 · ⌘Enter 后台新标签</span></div></div>`;
}
function previewView() {
  let layer = '';
  if (state.preview && state.scheme === 'a') layer = `<div class="preview-layer"><div class="preview-modal">${previewContent()}<p class="meta">Space / Esc 关闭 · ← / → 切换 · 不自动创建标签</p></div></div>`;
  if (state.preview && state.scheme === 'c') layer = `<aside class="peek">${previewContent()}<p class="meta">Space / Esc 关闭 · 原列表仍可看见</p></aside>`;
  const right = state.preview && state.scheme === 'b' ? `<aside class="inspector"><h3>快速预览 · 非模态</h3>${previewContent()}<p class="meta">焦点仍在预览；Esc 返回原结果</p></aside>` : '';
  const body = `<div class="app-body" style="grid-template-columns:${right ? 'minmax(0,1fr) 240px' : 'minmax(0,1fr)'}"><main>${resultPane(false, state.scheme !== 'a')}</main>${right}</div>`;
  if (state.scheme === 'a') return notionShell(body, layer, 'tabs');
  return `<div class="app-window">${windowTitle()}${body}${layer}</div>`;
}
function readerView() {
  const immersive = state.scheme === 'a' && state.readerMode === 'immersive';
  const reader = `<div class="reader ${state.chrome ? '' : 'chrome-hidden'} ${immersive ? 'reader-immersive' : ''}" data-reader-mode="${immersive ? 'immersive' : 'normal'}"><div class="reader-top"><span>‹ ${titles[state.readingIndex]}</span><span>第 18 话 · 信标</span><span class="reader-tools"><button class="reader-tool" data-action="chapters" aria-pressed="${state.chapters}">章节</button><span class="reader-tool">阅读方案</span>${state.scheme === 'a' ? `<button class="reader-tool" data-action="readerMode">${immersive ? '退出沉浸 · Esc' : '沉浸阅读'}</button>` : ''}<span class="reader-tool">⋯</span></span></div><div class="reader-page" data-action="chrome" title="单击漫画区域，切换阅读工具"><div class="paper"><i></i><i></i><i></i><i></i><i></i></div></div>${state.chapters && state.chrome ? '<aside class="reader-side" aria-label="章节浮层"><div class="reader-side-head"><b>章节</b><span>Esc 关闭</span></div><div class="chapter"><span>第 20 话</span><span>›</span></div><div class="chapter"><span>第 19 话</span><span>✓</span></div><div class="chapter"><span>第 18 话</span><span>当前</span></div></aside>' : ''}<div class="reader-bottom" aria-label="阅读进度 18 / 24"><span class="reader-step">‹</span><div class="progress"></div><span class="reader-page-count">18 / 24</span><span class="reader-step">›</span></div></div>`;
  if (immersive) return `<div class="app-window immersive-window">${reader}</div>`;
  if (state.scheme === 'a') return notionShell(reader, '', 'tabs');
  return reader;
}
function actionButton(action, label, pressed = null) { return `<button class="demo-button" data-action="${action}" ${pressed === null ? '' : `aria-pressed="${pressed}"`}>${label}</button>`; }
function actions() {
  const list = [];
  if (state.scheme === 'a') {
    list.push(actionButton('narrow', state.narrow ? '恢复宽窗口' : '演示窄窗口', state.narrow));
    list.push(actionButton('largeText', state.largeText ? '恢复标准文字' : '演示大文字 · 150%', state.largeText));
  }
  if (state.scheme === 'a' && ['favorites', 'shelf'].includes(state.task)) {
    list.push(actionButton('density:comfortable', '舒适密度', state.density === 'comfortable'));
    list.push(actionButton('density:compact', '紧凑密度', state.density === 'compact'));
  }
  if (state.scheme === 'a' && state.task !== 'reader') {
    const sidebarVisible = state.narrow ? state.sidebarOverlay : state.sidebar;
    const label = state.narrow ? (sidebarVisible ? '关闭侧栏浮层' : '打开侧栏浮层') : (sidebarVisible ? '收起侧栏' : '展开侧栏');
    list.push(actionButton('sidebar', label, sidebarVisible));
  }
  if (state.task === 'favorites') list.push(actionButton('select', state.selected ? '退出多选' : '演示多选', state.selected));
  if (state.task === 'shelf') ['collapsed','normal','expanded'].forEach(mode => list.push(actionButton(`shelf:${mode}`, {collapsed:'折叠',normal:'正常',expanded:'展开'}[mode], state.shelf === mode)));
  if (state.scheme === 'a' && state.task === 'tabs') {
    const states = { loading: '首次加载', refreshing: '更新中', empty: '无结果', error: '更新失败' };
    Object.entries(states).forEach(([status, label]) => list.push(actionButton(`resultStatus:${status}`, label, state.resultStatus === status)));
    if (state.resultStatus !== 'ready') list.push(actionButton('resultStatus:ready', '正常结果'));
    const closeLabels = { recent: '最近浏览', right: '右侧标签', left: '左侧标签' };
    list.push(actionButton('closeBehavior', `关闭标签后：${closeLabels[state.closeBehavior]}`));
    const onDetail = state.activeTab === 'detail' || state.addedTabs.some(tab => tab.id === state.activeTab);
    if (onDetail) {
      list.push(actionButton('detailLayout:reading', '阅读优先', state.detailLayout === 'reading'));
      list.push(actionButton('detailLayout:info', '信息优先', state.detailLayout === 'info'));
    }
    list.push(actionButton('startup:restore', '重启后：恢复上次标签', state.startup === 'restore'));
    list.push(actionButton('startup:fresh', '重启后：收藏首页', state.startup === 'fresh'));
  }
  if (state.scheme === 'a' && (state.task === 'tabs' || state.task === 'preview') && !['loading', 'empty'].includes(state.resultStatus)) {
    list.push(actionButton('clickBehavior', `点击漫画：${state.clickBehavior === 'detail' ? '进入详情' : '直接阅读'}`));
    list.push(actionButton('demoMulti', state.selectedResults.length ? `已选 ${state.selectedResults.length} 部 · 清空` : '演示多选', state.selectedResults.length > 0));
    list.push(actionButton('openSelection', state.selectedResults.length ? `在 ${state.selectedResults.length} 个后台标签打开` : '后台打开当前漫画'));
    list.push(actionButton('demoOverflow', '演示标签溢出'));
  }
  if (state.task === 'tabs' && state.scheme !== 'a') list.push(actionButton('split', state.split ? '关闭分屏' : '并排对照', state.split));
  if (state.task === 'preview') {
    list.push(actionButton('preview', state.preview ? '关闭预览' : '空格：快速预览', state.preview));
    if (state.preview) {
      ['overview','chapters','details'].forEach(section => list.push(actionButton(`previewSection:${section}`, {overview:'概览',chapters:'目录',details:'详情'}[section], state.previewSection === section)));
      list.push(actionButton('previous','← 上一部'), actionButton('next','下一部 →'));
      list.push(actionButton('promote','Enter 当前标签'), actionButton('promoteNew','⌘Enter 后台新标签'));
    }
  }
  if (state.task === 'reader') {
    if (state.scheme === 'a') list.push(actionButton('readerMode', state.readerMode === 'immersive' ? '退出沉浸 · Esc' : '进入沉浸阅读', state.readerMode === 'immersive'));
    list.push(actionButton('chrome', state.chrome ? '隐藏阅读工具' : '显示阅读工具', state.chrome));
    if (state.chrome) list.push(actionButton('chapters', '章节浮层', state.chapters));
  }
  list.push(actionButton('reduceMotion', state.reducedMotion ? '恢复动效演示' : '演示减少动画', state.reducedMotion));
  const accents = { blue: '雾蓝', green: '青绿', ochre: '暖黄' };
  list.push(actionButton('accent', `强调色：${accents[state.accent]}`));
  list.push(actionButton('theme', state.theme === 'light' ? '切到深色' : '切到浅色'));
  return list.join('');
}
function render() {
  document.documentElement.dataset.theme = state.theme;
  document.documentElement.dataset.accent = state.accent;
  document.documentElement.classList.toggle('reduce-motion', state.reducedMotion);
  document.querySelectorAll('[data-scheme]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.scheme === state.scheme)));
  document.querySelectorAll('[data-task]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.task === state.task)));
  document.getElementById('view-title').textContent = `${schemes[state.scheme].name} / ${tasks[state.task]}`;
  document.getElementById('demo-actions').innerHTML = actions();
  const canvas = document.getElementById('canvas');
  canvas.classList.toggle('demo-narrow', state.scheme === 'a' && state.narrow);
  canvas.classList.toggle('demo-large-text', state.scheme === 'a' && state.largeText);
  canvas.classList.toggle('density-compact', state.scheme === 'a' && state.density === 'compact');
  canvas.innerHTML = ({favorites, shelf: shelfView, tabs: tabsView, preview: previewView, reader: readerView})[state.task]();
  document.getElementById('feel').textContent = schemes[state.scheme].feel;
  document.getElementById('cost').textContent = state.notice || schemes[state.scheme].cost;
  document.querySelectorAll('[data-action]').forEach(button => button.addEventListener('click', () => act(button.dataset.action)));
  bindDragAndDrop();
  requestAnimationFrame(() => {
    const region = document.querySelector('.tab-scroll-region');
    const active = region?.querySelector('.doc-tab.active');
    if (region && active && region.scrollWidth > region.clientWidth) active.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  });
}
function focusPreviewResult() { document.querySelector(`[data-action="openResult:${state.previewIndex}"]`)?.focus(); }
function markTabActive(id) {
  state.activeTab = id;
  state.tabRecency = [id, ...state.tabRecency.filter(tabId => tabId !== id)];
}
function openNewComicTabs(indices, before = null) {
  const current = state.activeTab === 'new' ? 'search' : state.activeTab;
  state.closedTabs = state.closedTabs.filter(id => id !== 'search');
  indices.forEach(index => {
    const tab = { id: `comic-${++state.tabSerial}`, label: `${titles[index]} · 详情`, state: '已加载 · 独立滚动与返回栈', comicIndex: index, loaded: false };
    state.addedTabs.push(tab);
    const insertAt = before && state.tabOrder.includes(before) ? state.tabOrder.indexOf(before) : state.tabOrder.length;
    state.tabOrder.splice(insertAt, 0, tab.id);
  });
  state.activeTab = current;
  state.preview = false;
  state.notice = `已创建 ${indices.length} 个后台标签，仍停留在原搜索页；详情将在首次激活时加载，不立即发起整批网络请求。`;
  render();
}
function openCurrentComic(index) {
  const current = state.activeTab === 'new' ? 'search' : state.activeTab;
  const tab = { id: `comic-${++state.tabSerial}`, label: `${titles[index]} · 详情`, state: '当前标签进入 · 搜索保留在返回栈', comicIndex: index, loaded: true };
  state.addedTabs.push(tab);
  state.tabHistory[tab.id] = { originId: current };
  const currentAt = state.tabOrder.indexOf(current);
  if (currentAt >= 0) state.tabOrder.splice(currentAt, 1, tab.id); else state.tabOrder.push(tab.id);
  markTabActive(tab.id);
  state.preview = false;
  state.task = 'tabs';
  state.notice = `当前标签已进入「${titles[index]}」，原搜索保留在返回栈；卡片点击与预览 Enter 共用这一规则。`;
  render();
}
function act(action) {
  state.notice = '';
  if (action !== 'tabMenu') state.tabMenu = false;
  if (action === 'tabMenu') state.tabMenu = !state.tabMenu;
  if (action === 'theme') state.theme = state.theme === 'light' ? 'dark' : 'light';
  if (action === 'accent') {
    const options = ['blue', 'green', 'ochre'];
    const labels = { blue: '雾蓝', green: '青绿', ochre: '暖黄' };
    state.accent = options[(options.indexOf(state.accent) + 1) % options.length];
    state.notice = `强调色示意已切换为“${labels[state.accent]}”；只改变当前位置、焦点、主操作与进度，不给封面或整个内容区染色。`;
  }
  if (action === 'reduceMotion') {
    state.reducedMotion = !state.reducedMotion;
    state.notice = state.reducedMotion ? '减少动画：取消预览位移、侧栏滑动、阅读工具淡入及骨架循环动画；所有操作仍立即可用。' : '已恢复克制的状态变化动效；操作不需要等待动画结束。';
  }
  if (action === 'narrow') {
    state.narrow = !state.narrow;
    state.sidebarOverlay = false;
    state.notice = state.narrow ? '窄窗口：侧栏自动退出但不改写宽窗口偏好；手动打开时覆盖内容，Esc 或点击外部关闭。' : '已恢复宽窗口，并还原此前记住的侧栏展开状态。';
  }
  if (action === 'largeText') {
    state.largeText = !state.largeText;
    state.notice = state.largeText ? '大文字 150%：卡片统一预留两行标题；导航、按钮和标签增加高度，次要内容允许换行或进入菜单。' : '已恢复标准文字与单行卡片标题，长名称省略规则不变。';
  }
  if (action.startsWith('density:')) {
    state.density = action.split(':')[1];
    state.notice = state.density === 'compact' ? '紧凑密度：增加同屏作品、减少间距，但不缩小文字，也不隐藏作者与更新信息。作者栏状态与排序保持不变。' : '舒适密度：保留较大的封面与留白，优先通过封面识别作品。';
  }
  if (action.startsWith('detailLayout:')) {
    state.detailLayout = action.split(':')[1];
    state.notice = state.detailLayout === 'reading' ? '阅读优先：先展示继续阅读与最近章节，完整简介和来源默认收起；功能没有减少。' : '信息优先：直接展示完整作品信息与简介，继续阅读和章节随后出现；只调整内容顺序与默认展开程度。';
  }
  if (action.startsWith('startup:')) {
    state.startup = action.split(':')[1];
    state.notice = state.startup === 'restore' ? '重启后恢复标签顺序、当前标签，以及各标签的搜索筛选、滚动位置和阅读页码；只立即加载当前标签，其余首次激活时再加载。' : '重启后只打开收藏首页，不自动恢复上次标签；此选择只影响下次启动，不会立即清除当前会话。';
  }
  if (action === 'favorite') {
    state.favorite = !state.favorite;
    state.notice = state.favorite ? '已加入收藏；收藏状态保留在当前详情页。' : '已取消收藏；其他详情信息与阅读进度不受影响。';
  }
  if (action === 'sidebar') {
    if (state.narrow) state.sidebarOverlay = !state.sidebarOverlay;
    else state.sidebar = !state.sidebar;
  }
  if (action === 'sidebarOverlayClose') state.sidebarOverlay = false;
  if (action.startsWith('resultStatus:')) {
    state.resultStatus = action.split(':')[1];
    if (['loading', 'empty'].includes(state.resultStatus)) state.selectedResults = [];
    state.preview = false;
    const notices = {
      ready: '已恢复可用的搜索结果；关键词与筛选条件保持不变。',
      loading: '首次加载：以同尺寸骨架保留网格位置，结果到达前不提供漫画操作。',
      refreshing: '正在更新来源；保留当前结果，更新期间仍可打开漫画。',
      empty: '没有匹配结果：保留关键词与筛选，可以清空筛选或尝试全部来源。',
      error: '来源更新失败：继续显示此前结果，明确提示可能不是最新；旧漫画仍可打开，也可以重试。'
    };
    state.notice = notices[state.resultStatus];
  }
  if (action === 'select') state.selected = !state.selected;
  if (action === 'historyBack') {
    const history = state.tabHistory[state.activeTab];
    if (!history) return;
    const currentAt = state.tabOrder.indexOf(state.activeTab);
    if (currentAt >= 0) state.tabOrder.splice(currentAt, 1, history.originId);
    state.closedTabs = state.closedTabs.filter(id => id !== history.originId);
    markTabActive(history.originId);
    state.preview = false;
    state.task = 'tabs';
    state.notice = '已返回原搜索页；关键词、筛选、多选与滚动位置均保留。关闭标签则会移除当前工作现场，两者互不等同。';
    render();
    focusPreviewResult();
    return;
  }
  if (action === 'clickBehavior') { state.clickBehavior = state.clickBehavior === 'detail' ? 'reader' : 'detail'; state.notice = `漫画卡片点击行为已切换为“${state.clickBehavior === 'detail' ? '进入详情' : '直接阅读'}”；此设置应适用于所有漫画列表。`; }
  if (action === 'closeBehavior') {
    const options = ['recent', 'right', 'left'];
    const labels = { recent: '最近浏览', right: '右侧标签', left: '左侧标签' };
    state.closeBehavior = options[(options.indexOf(state.closeBehavior) + 1) % options.length];
    state.notice = `关闭当前标签后跳转到“${labels[state.closeBehavior]}”。正式实现放入设置；后台创建但未查看的标签不计入最近浏览顺序。`;
  }
  if (action.startsWith('shelf:')) state.shelf = action.split(':')[1];
  if (action.startsWith('tab:')) {
    markTabActive(action.split(':')[1]);
    const tab = state.addedTabs.find(item => item.id === state.activeTab);
    if (tab) tab.loaded = true;
  }
  if (action.startsWith('focusResult:')) state.previewIndex = Number(action.split(':')[1]);
  if (action.startsWith('openResult:')) {
    const index = Number(action.split(':')[1]);
    state.previewIndex = index;
    state.readingIndex = index;
    if (state.clickBehavior === 'detail') { openCurrentComic(index); return; }
    state.preview = false;
    state.task = 'reader';
    state.sidebar = false;
    state.chrome = true;
    state.chapters = false;
    state.notice = `已按全局卡片点击设置直接阅读「${titles[index]}」。`;
  }
  if (action.startsWith('selectResult:')) {
    const index = Number(action.split(':')[1]);
    state.previewIndex = index;
    state.lastSelected = index;
    state.selectedResults = state.selectedResults.includes(index) ? state.selectedResults.filter(i => i !== index) : [...state.selectedResults, index];
    state.notice = '复选框只切换选择，不打开漫画；再次点击卡片主体仍会正常打开。';
  }
  if (action === 'demoMulti') { state.selectedResults = state.selectedResults.length ? [] : [0,2,3]; state.lastSelected = 2; }
  if (action === 'demoOverflow') { openNewComicTabs([0,1,2,3,4,5,6,7]); return; }
  if (action === 'openSelection') { openNewComicTabs(state.selectedResults.length ? state.selectedResults : [state.previewIndex]); return; }
  if (action.startsWith('openResultNew:')) { openNewComicTabs([Number(action.split(':')[1])]); return; }
  if (action.startsWith('close:')) {
    const id = action.split(':')[1];
    const tabs = aTabs();
    const index = tabs.findIndex(tab => tab.id === id);
    const recent = state.tabRecency.find(tabId => tabId !== id && tabs.some(tab => tab.id === tabId));
    const directional = state.closeBehavior === 'left' ? tabs[index - 1]?.id || tabs[index + 1]?.id : tabs[index + 1]?.id || tabs[index - 1]?.id;
    const nextId = state.closeBehavior === 'recent' ? recent : directional;
    if (index >= 0 && !state.closedTabs.includes(id)) state.closedTabs.push(id);
    if (state.activeTab === id) {
      const remaining = aTabs();
      const fallback = remaining[Math.min(index, remaining.length - 1)]?.id || 'new';
      markTabActive(nextId && remaining.some(tab => tab.id === nextId) ? nextId : fallback);
      state.notice = `已关闭当前标签，并按“${{ recent: '最近浏览', right: '右侧标签', left: '左侧标签' }[state.closeBehavior]}”规则跳转。`;
    }
  }
  if (action === 'addTab') {
    const restored = state.closedTabs.shift();
    if (restored) { markTabActive(restored); state.notice = '已恢复一个关闭的标签，用于演示标签状态不会随关闭按钮以外的操作丢失。'; }
    else state.notice = '当前示例标签都已打开；真实产品中此时会新建一个空白搜索标签。';
  }
  if (action === 'split') state.split = !state.split;
  if (action === 'preview') state.preview = !state.preview;
  if (action.startsWith('previewSection:')) state.previewSection = action.split(':')[1];
  if (action === 'previous' || action === 'next') state.previewIndex = (state.previewIndex + (action === 'next' ? 1 : 3)) % 4;
  if (action === 'promote') { openCurrentComic(state.previewIndex); return; }
  if (action === 'promoteNew') { openNewComicTabs([state.previewIndex]); return; }
  if (action === 'readerMode') {
    state.readerMode = state.readerMode === 'immersive' ? 'normal' : 'immersive';
    state.chrome = true;
    state.chapters = false;
    state.sidebarOverlay = false;
    state.notice = state.readerMode === 'immersive' ? '沉浸阅读：多标签栏隐藏；单击漫画任意位置切换阅读工具，Esc 返回普通模式。' : '普通阅读：多标签栏常驻；单击漫画任意位置切换阅读工具。';
  }
  if (action === 'chrome') {
    state.chrome = !state.chrome;
    if (!state.chrome) state.chapters = false;
  }
  if (action === 'chapters') {
    state.chapters = !state.chapters;
    state.chrome = true;
    state.notice = state.chapters ? '章节以右侧浮层覆盖漫画，不改变页面尺寸；Esc 先关闭浮层。' : '';
  }
  render();
  if (action === 'preview' && !state.preview) focusPreviewResult();
}
function clearDragVisuals() {
  document.querySelectorAll('.drop-before, .drag-over, .drop-end, .drag-source').forEach(element => element.classList.remove('drop-before', 'drag-over', 'drop-end', 'drag-source'));
  document.querySelectorAll('.drop-feedback').forEach(element => { element.textContent = ''; });
  document.getElementById('drag-badge')?.remove();
}
function cancelDrag() { state.dragging = null; clearDragVisuals(); }
function positionDragBadge(event) {
  const badge = document.getElementById('drag-badge');
  if (badge && Number.isFinite(event.clientX)) { badge.style.left = `${event.clientX + 14}px`; badge.style.top = `${event.clientY + 14}px`; }
}
function bindDragAndDrop() {
  if (state.scheme !== 'a' || (state.task !== 'tabs' && state.task !== 'preview')) return;
  document.querySelectorAll('[data-comic-index]').forEach(card => {
    const setPreviewTarget = () => {
      state.previewIndex = Number(card.dataset.comicIndex);
      document.querySelectorAll('[data-comic-index]').forEach(item => item.classList.toggle('active', item === card));
    };
    card.addEventListener('pointerenter', setPreviewTarget);
    card.addEventListener('focusin', setPreviewTarget);
    card.addEventListener('dragstart', event => {
      const index = Number(card.dataset.comicIndex);
      const indices = state.selectedResults.includes(index) ? [...state.selectedResults] : [index];
      state.dragging = { indices, before: null };
      event.dataTransfer.effectAllowed = 'copy';
      event.dataTransfer.setData('text/plain', indices.join(','));
      card.classList.add('drag-source');
      const badge = document.createElement('div');
      badge.id = 'drag-badge';
      badge.textContent = `${indices.length} 部漫画 · 拖到标签栏`;
      document.body.appendChild(badge);
      positionDragBadge(event);
    });
    card.addEventListener('dragend', cancelDrag);
    card.addEventListener('contextmenu', event => { event.preventDefault(); act(`openResultNew:${card.dataset.comicIndex}`); });
  });
  const zone = document.querySelector('[data-tab-dropzone]');
  if (!zone) return;
  const region = zone.querySelector('.tab-scroll-region');
  zone.addEventListener('dragover', event => {
    if (!state.dragging) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
    zone.classList.add('drag-over');
    region?.classList.remove('drop-end');
    zone.querySelectorAll('.drop-before').forEach(element => element.classList.remove('drop-before'));
    const target = event.target.closest('.doc-tab');
    state.dragging.before = target?.dataset.tabId || null;
    if (target) target.classList.add('drop-before'); else region?.classList.add('drop-end');
    const targetLabel = target?.querySelector('.tab-main')?.textContent || '标签末尾';
    document.querySelectorAll('.drop-feedback').forEach(element => { element.textContent = `松开：在「${targetLabel}」前创建 ${state.dragging.indices.length} 个后台标签 · Esc 取消`; });
    positionDragBadge(event);
  });
  zone.addEventListener('dragleave', event => {
    if (zone.contains(event.relatedTarget)) return;
    zone.classList.remove('drag-over');
    region?.classList.remove('drop-end');
    zone.querySelectorAll('.drop-before').forEach(element => element.classList.remove('drop-before'));
  });
  zone.addEventListener('drop', event => {
    event.preventDefault();
    if (!state.dragging) return;
    const { indices, before } = state.dragging;
    state.dragging = null;
    clearDragVisuals();
    openNewComicTabs(indices, before);
  });
}
document.querySelectorAll('[data-scheme]').forEach(button => button.addEventListener('click', () => { state.scheme = button.dataset.scheme; state.tabMenu = false; state.sidebarOverlay = false; state.notice = ''; render(); }));
document.querySelectorAll('[data-task]').forEach(button => button.addEventListener('click', () => {
  if (!['tabs', 'preview'].includes(button.dataset.task)) state.resultStatus = 'ready';
  state.task = button.dataset.task;
  state.tabMenu = false;
  state.sidebarOverlay = false;
  state.notice = '';
  if (state.task === 'reader' && state.scheme === 'a') {
    state.sidebar = false;
    state.chrome = true;
    state.chapters = false;
    state.notice = state.readerMode === 'immersive' ? '沉浸阅读：Esc 返回普通模式；单击漫画任意位置切换阅读工具。' : '普通阅读：标签常驻；单击漫画任意位置切换阅读工具，不再自动隐藏。';
  }
  render();
}));
document.addEventListener('dragover', event => { if (state.dragging) positionDragBadge(event); });
document.addEventListener('keydown', event => {
  const command = event.ctrlKey || event.metaKey;
  const aWorkspace = state.scheme === 'a' && (state.task === 'tabs' || state.task === 'preview');
  const aResultsAvailable = aWorkspace && !['loading', 'empty'].includes(state.resultStatus);
  if (event.key === 'Escape' && state.dragging) { event.preventDefault(); cancelDrag(); state.notice = '已取消拖动，没有创建标签。'; render(); return; }
  if (event.key === 'Escape' && state.tabMenu) { event.preventDefault(); state.tabMenu = false; render(); document.querySelector('[data-action="tabMenu"]')?.focus(); return; }
  if (event.key === 'Escape' && state.sidebarOverlay) {
    event.preventDefault();
    state.sidebarOverlay = false;
    state.notice = '已关闭窄窗口侧栏浮层；宽窗口侧栏偏好未改变。';
    render();
    document.querySelector('.workspace-top .shell-toggle')?.focus();
    return;
  }
  if (state.task === 'reader' && event.key === 'Escape') {
    event.preventDefault();
    if (state.chapters) {
      state.chapters = false;
      state.chrome = true;
      state.notice = '已先关闭章节浮层，仍未退出当前阅读模式。';
      render();
      document.querySelector('.reader-top [data-action="chapters"]')?.focus();
      return;
    }
    if (state.scheme === 'a' && state.readerMode === 'immersive') {
      state.readerMode = 'normal';
      state.chrome = true;
      state.notice = '已退出沉浸阅读，多标签栏恢复；章节与页码保持不变。';
      render();
      return;
    }
    if (!state.chrome) {
      state.chrome = true;
      state.notice = '已找回阅读工具；再次单击漫画任意位置即可隐藏。';
      render();
      return;
    }
  }
  if (aResultsAvailable && state.task === 'preview' && state.preview && command && event.key === 'Enter') { event.preventDefault(); act('promoteNew'); return; }
  if (aResultsAvailable && !state.preview && command && event.key === 'Enter') { event.preventDefault(); act('openSelection'); return; }
  if (aWorkspace && command && event.key.toLowerCase() === 't') { event.preventDefault(); act('addTab'); return; }
  if (aWorkspace && command && event.key.toLowerCase() === 'w') { event.preventDefault(); if (state.activeTab !== 'new') act(`close:${state.activeTab}`); return; }
  if (aWorkspace && command && event.key === 'Tab') {
    event.preventDefault();
    const tabs = aTabs();
    const index = tabs.findIndex(tab => tab.id === state.activeTab);
    if (tabs.length) act(`tab:${tabs[(index + (event.shiftKey ? -1 : 1) + tabs.length) % tabs.length].id}`);
    return;
  }
  if (aWorkspace && event.altKey && event.key === 'ArrowLeft' && state.tabHistory[state.activeTab]) { event.preventDefault(); act('historyBack'); return; }
  if (command || event.altKey || /INPUT|TEXTAREA|SELECT/.test(event.target.tagName)) return;
  if (aResultsAvailable && event.code === 'Space') { event.preventDefault(); if (!state.preview) state.task = 'preview'; act('preview'); }
  if (state.task === 'preview' && state.preview && event.key === 'Escape') { event.preventDefault(); state.preview = false; render(); focusPreviewResult(); return; }
  if (aWorkspace && event.key === 'Escape' && state.selectedResults.length) {
    event.preventDefault();
    state.selectedResults = [];
    state.notice = '已清空所有漫画选择。';
    render();
    document.querySelector(`[data-action="openResult:${state.lastSelected}"]`)?.focus();
    return;
  }
  if (state.task === 'preview' && state.preview && (event.key === 'ArrowLeft' || event.key === 'ArrowRight')) { event.preventDefault(); act(event.key === 'ArrowLeft' ? 'previous' : 'next'); }
  if (state.task === 'preview' && state.preview && event.key === 'Enter') { event.preventDefault(); act('promote'); }
});
render();
