# B5 双面翻页额外上下黑边修复

基线10a4d79，工件以派工HEAD为准。按顺序执行，每项完成立即勾选并写命令/结果/证据备注。未复现不做猜测修复；设计冲突交architect。

- [x] 1.1 核对HEAD和干净工作区，读最小清单/诊断/UI技能；生产ReaderGalleryView（必要时真实Reader接入）建立同图同窗口单双面对照的可重复真实渲染红灯，记录原图/viewport/黑带像素与四边标记、具体控件与配置，排除loading/harness失败；最小化后列3–5可证伪假设及单变量探针，确认真实根因。若只有必要留白或无法复现，先交付尝试矩阵和样本局限，不虚构红灯或自行改适配策略。
  - 备注：真实ReaderScaffold固定左/右栏1040×700、同600×900图单面y0..699/双面y66..633；匹配viewport18格全绿，真实外围10格8绿2红；正式回归修复前10通过7失败0skip。4假设及逐项证据/根因见delivery.md；仅受控生产配置复现，未冒称owner原始输入。
- [x] 1.2 按D2/D3实施最小修复及回归红绿；D4相关窗口/方向/图片比例/首尾/跨页/延迟加载及resize有真实渲染证据，四边完整等比，单面及其他模式保持，原交互和配置语义不回退，不改用户默认值/图片数据；移除临时探针。共享组件范围扩大先报architect。
  - 备注：仅gallery双面customChild删除窗口childSize覆盖，默认采用实际约束；正式17测试全通过(修复前10通过7失败)，原真实外围10格全绿；混合比例/LTR/RTL/纵向/首图/跨页独占/奇尾/resize390/800/1280/返回及两主题、chrome、1.6文本/减少动画均有实际像素断言，1.5px容差。无共享组件/适配/配置变更或临时生产探针。
- [x] 1.3 运行新增与受影响原回归（保留原断言，按改动说明B3/F9等保护范围），列真实通过/失败/skip；analyze raw/unique50=38+12具体集合零新增，protected零diff、翻译/SHA/diffcheck/OpenSpec通过，不修无关基线/不重生成lock。
  - 备注：executor相关148通过0失败0skip；仅清理已批准多余import后新增17再次通过。analyze前后raw/unique均50=38+12，added=[] removed=[]见/tmp/b5-analyze-comparison.json；architect独立同结论。protected零diff、diffcheck、OpenSpec通过；无新增UI文案/翻译变更、图片未入库/lock未动；两源码SHA与命令见delivery。
- [x] 1.4 最终源码GUI真实单双面前后证据，至少宽桌面两主题及resize/首尾保护，窗口标题/PID/隔离与稳定帧逐张核对；截图仅/tmp。正常main构建恢复，停本轮fixture并核对ps/X11；delivery.md汇总根因、红绿命令/计数、改动SHA、实际矩阵/局限、保护/构建清理，等architect独立复核，不提交/归档/push。

  - 备注：真实原生GUI PID573551/window0xa00002，浅深单双面/chrome、真实resize800再1280、异比/首图/跨页/奇尾/返回已逐张view_image，记录/tmp/b5-gui/matrix.json及delivery；真实double/drag已发并释放、稳定恢复，但未接整页GestureHost，scale仍1，不能冒称GUI缩放或生产键盘绑定覆盖。宿主1080×760，完整1280帧为RepaintBoundary导出。正常main构建成功，已正常退出仅自身fixture，ps/X11经architect独立核对清理；未提交/归档/push。
