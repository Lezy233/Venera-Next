# B5 双面翻页额外上下黑边修复

## Why

owner反馈同一漫画在「双面翻页」上下各有一段黑边，「单面翻页」没有。当前仅有症状，尚无已证实根因；必须先以生产阅读组件、相同内容及窗口建立单双面差异的真实渲染红灯。

## What Changes

- 诊断并最小修复双面翻页额外占用阅读高度或额外绘制上下黑带的问题。
- 保留原图比例、完整边缘、现有翻页顺序、缩放/拖动、单面及其他阅读模式。
- 新增最终渲染/实际图片边界回归，不以回调或单纯布局属性代替可见结果。

## Scope

入口为lib/features/reader/gallery_view.dart、gallery_data.dart、comic_image.dart、images_host.dart、page_layout.dart、reader.dart及直接依赖；先从公开生产组件ReaderGalleryView与现有gallery_input_test.dart开始构造反馈循环。仅可修改证据指向的相关实现与测试。不是全阅读器重构，不改自动模式判定、方案绑定/继承、用户设置、图片文件或解码处理语义，不启动F11/F1/F2/UX1。

design-spec.md §1/2/4/7.4适用：阅读器chrome随主题，不引入深色例外、不靠改黑边颜色掩盖几何错误。不可在未复现时假定padding、BoxFit或第三方库是唯一根因。若根本原因只是等比完整显示的必要留白或原图本身黑边，须报告证据给architect再裁定，不自动裁切/拉伸或改默认适配策略。

## Status

2026-11-06 owner要求安排B5；实现前基线10a4d794a9f70aecb42b7b51ba3cdeadfd905941。四件套提交到HEAD后派executor新会话，逐项执行tasks并备注；architect批准前不提交实现，owner验收前不归档/push。
