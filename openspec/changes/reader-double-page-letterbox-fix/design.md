# B5 设计与诊断边界

## D1 已知事实与最小上下文

owner只确认双面翻页有额外上下黑边、单面无此问题；未提供漫画页、窗口和设置组合，不将猜测写成根因。planner只定位公开组件/测试入口，不做实现debug。executor先读AGENTS/ROADMAP/本change四件套、design-spec §1/2/4/7.4及诊断/UI技能；若存在相关CONTEXT/ADR才按指针读取，不全库探索。入口ReaderGalleryView/ReaderGalleryData、comic_image.dart、images_host.dart、page_layout.dart、reader.dart，已有gallery_input、dual_page_split、page_layout、page_navigation测试可复用。

## D2 正确行为与不可扩大的范围

同一可用阅读viewport、同一原图及配置下，双面完整显示应使用实际可用区域，无双面路径额外引入的上下遮挡或无依据的高度损失。对照必须记录图片原始尺寸、实际viewport/内容约束、两张图的实际渲染边界、当前缩放/适配和主题；单双面横向空间不同，不能要求两者任意输入下占高完全相同。

保持原图等比和完整显示；原图中自带的黑边、正常等比适配必需的留白不属于可用裁切消除的缺陷。用显著非黑背景、四边标记及网格的受控原图区分源图/可用空间/覆盖层/实际图像边界，测试素材运行时生成，不提交图片。不同宽高比导致的必要留白不可通过cover裁切、非等比填充、强制放大、默认缩放变更或重新配色“修复”。若复现只剩必要留白、须改适配策略或缺用户特定输入，列出已尝试矩阵和证据，交architect；未经裁定不选择产品取舍。

不改页序、首图单页、已识别跨页图独占一页、奇数尾页、方向、当前图片到页码映射及历史定位。保持默认和手动阅读模式、方案同ID持续编辑/跟随默认、来源/漫画/章节身份与读图次数语义。双面同组不同图比例不应遗漏/拉伸，隐藏chrome和显示chrome的可用区都要按真实布局解释。

## D3 反馈循环与最小修复

使用/home/_Le/.agents/skills/diagnosing-bugs/SKILL.md：先真实生产ReaderGalleryView（必要时整ReaderPage接入）建立可重复红灯命令；记录确切黑带位置、像素/原图四边标记和实际图像边界，确认不是harness缺尺寸或加载失败。固定输入/主题/窗口/方向/配置，单面为对照；不只测试自写几何helper或直接调用回调。

先复现最小化，再列3–5个可证伪假设并按序单变量验证；每次保留命令与信号，记录真实根因。图像需实际解码就绪，等待稳定帧；失败loading占位、PhotoView未attach、测试环境未初始化不当作产品红灯。允许在相关实现添加可复用最小测试seam，但不能替换生产渲染路径或为fixture修改正常main/runner。首轮不能复现时先提供尝试及样本局限，不虚构owner场景。

最小修复仅改变已证实错误的布局/绘制路径及直接测试，相关共享ComicImage如需修改须说明对单面/连续/瀑布流的作用范围后由architect复核，不升级第三方库或新增依赖。临时探针带唯一前缀，交付前移除。.agents/skills/ui-ux-pro-max/SKILL.md只检查图像布局、主题、缩放、命中和手势回归，不生成新视觉体系。design-spec.md及正式spec由planner维护，executor不得修改。

## D4 验证矩阵

| 场景 | 必须证据 |
|---|---|
| 原始症状 | 相同输入/viewport/配置单双面真实渲染；黑带位置/像素、原图尺寸及四边标记，生产双面红灯、单面正对照；修复后同命令绿 |
| 窗口与图片 | 桌面1280×700及800×600；运行中resize；双面等比高图、不同高宽比配对、横向跨页图、奇数尾页和首图单页；390窄窗按现有规则保护，不另造阈值 |
| 方向及加载 | 左→右/右→左双面；既有支持的纵向翻页保护；延迟解码/重建、下一页/返回，不出现一次性错误高度或残留遮挡 |
| 完整性 | 四边标记保留、比例正确，无额外裁切/拉伸，缩放初值与用户设置不改；真实图像渲染和可用viewport对应 |
| 原交互 | 真实坐标翻页/键盘、缩放及拖动、双击、首尾/章节/历史映射；未改行为的相关原测试断言保留 |
| 其他模式 | 单面主对照、连续/瀑布流与跨页切分相关回归；若共享组件未变可合理缩小测试集合并说明 |
| 主题与chrome | 浅深主题均验证，chrome显示/隐藏跟随应用主题；不靠主题黑底让差异消失；1.6文字/减少动画下无额外布局遮挡 |
| 方案保护 | 若触及reader配置接入，复跑B3/F9相关绑定/继承/顺序；不修改设置值或绑定以取得截图 |

不要求不同布局相同缩放占高；assert实际可用区域、比例及完整边缘。几何允许合理亚像素误差并写明，不能放大容差吞掉可见黑带。新增测试覆盖确定根因和相关矩阵，避免对无关组件写镜像测试。

## D5 环境、保护与交付

所有fvm前export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897；fvm3.47.7，Flutter均--no-pub。原生LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib；必要时RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu。pub-cache仅允许已知pdfrx_engine-0.4.5四处cache→cache!环境补丁，注明不入库，不改lock/加依赖。

GUI DISPLAY=:1 GDK_BACKEND=x11，隔离XDG/业务/cache到本轮/tmp，windowManager.ensureInitialized/show。只操作读核标题/PID/proc后的本轮fixture，helper新版本先由architect完整核对；用合理窄前缀审批，权限由architect处理。实际宿主尺寸先xwininfo确认；完整1280图可用RepaintBoundary，不用宿主裁切冒充。每次输入release等稳定再逐张view_image；截图只/tmp。临时harness仅/tmp，正常main/runner不动。末尾恢复正常main构建并独立ps/X11确认仅自身fixture清理。

任务逐项即时勾选备注，delivery.md记录红绿命令/根因/真实坐标与像素边界、实际新增与相关回归通过失败skip计数、analyze raw/unique50=38+12具体集合零新增（不修基线）、改动清单/SHA、protected零diff、diffcheck/OpenSpec、GUI图及精确场景/局限、正常构建及清理。既有folder_creation_presentation两失败及folder_order_ownership静态基线排除如有涉及逐项说明，不以此吞新失败。此前F10实现为保护基线，不改其代码/工件。无新UI文案预期；确需新文案须.tl+zh_CN/zh_TW。architect批准前不提交；owner验收前不归档/push，不启动其他change。
