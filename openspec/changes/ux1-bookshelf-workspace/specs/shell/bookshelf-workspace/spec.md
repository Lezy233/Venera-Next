## ADDED Requirements

### Requirement: A 书架型桌面壳层

桌面 medium/expanded SHALL 使用可收起的左侧书架导航与右侧工作区，工作区顶栏 SHALL 承载当前位置的搜索、历史与标签。macOS 交通灯右侧 SHALL 提供侧栏开关，页面 MUST NOT 自造第二套窗口框架或引入分屏。

#### Scenario: 收起侧栏保留工作现场

- **WHEN** 用户在收藏或搜索中已滚动并选择漫画后收起侧栏
- **THEN** 右侧工作区扩展，当前内容、选择和滚动位置保持，侧栏入口仍可使用

#### Scenario: 顶栏归属右侧工作区

- **WHEN** 用户展开或收起左侧导航
- **THEN** 搜索、历史与标签随右侧工作区调整，不横跨或遮挡左侧导航

### Requirement: 窄窗口覆盖侧栏与宽度偏好恢复

compact 桌面窗口 SHALL 默认退出侧栏；用户主动打开时 SHALL 以浮层覆盖内容，并支持遮罩点击或 Escape 关闭。进入窄窗口 MUST NOT 覆盖用户此前保存的宽窗口侧栏偏好，恢复宽度后 SHALL 还原该偏好。

#### Scenario: 窄窗口打开再关闭侧栏

- **WHEN** 用户在窄窗口打开侧栏并点击内容遮罩
- **THEN** 侧栏关闭，正文尺寸和当前标签现场保持，宽窗口偏好未被改写

#### Scenario: 从窄窗口恢复宽窗口

- **WHEN** 用户进入窄窗口前已收起侧栏，随后恢复宽窗口
- **THEN** 宽窗口仍保持收起，不因窄窗口临时操作自动展开

### Requirement: 一致视觉与可访问反馈

新增壳层和内容控件 SHALL 使用 design-spec 的 token、语义颜色、Material Icons 与 `.tl`。动态强调色 SHALL 只用于当前位置、焦点、主操作与进度；hover、pressed、selected、focus 和 disabled SHALL 可区分，纯图标控件 SHALL 有可访问名称和 tooltip。

#### Scenario: 键盘浏览壳层控件

- **WHEN** 用户仅用 Tab、Enter 和 Space 操作侧栏、搜索与标签
- **THEN** 焦点始终可见，控件名称和状态可朗读，动作只触发一次

### Requirement: 大文字与减少动画

150% 大文字下，漫画卡片 SHALL 统一预留两行标题，导航和控件 SHALL 增加可用高度；完整名称 SHALL 可通过悬停或语义获取。手动及系统减少动画 SHALL 取消非必要位移、淡入和循环动画，且 MUST NOT 隐藏功能或延迟操作。

#### Scenario: 长名称在大文字窄窗口中显示

- **WHEN** 用户使用窄窗口、150% 大文字和超长漫画名称
- **THEN** 卡片标题最多两行且无溢出，导航和标签仍可操作，完整名称可获取

#### Scenario: 减少动画时连续切换

- **WHEN** 用户启用减少动画并快速切换标签、预览和侧栏
- **THEN** 状态立即更新，无残留动画层或焦点阻塞
