# B5 architect 独立复核

2026-11-06，实现阶段HEAD b4a27060d9a2615d8dc948024521de8d38bf44fc。受控生产配置复现及修复符合D2/D3；等待owner人工验收，不提交、归档或push。owner原始漫画/窗口/配置未提供，不能声称复现其全部输入。

## 根因与变更范围

生产ReaderScaffold固定缩略图左/右栏占240宽后，窗口MediaQuery仍1280×700，实际ReaderGalleryView为1040×700。双面传窗口尺寸作PhotoView.customChild的childSize，内层图片先按窗口适配，再把整窗口缩入较窄viewport，造成0.8125的二次缩小；600×900原图高度从700降至568.75，上下各约65.625px。单面路径不受此覆盖影响。

18格完整viewport正对照全部通过；人工减宽只算探针。接真实ReaderScaffold/ReaderThumbnailsView后，固定左右栏双面红、同配置单面绿，折叠/浮动/固定底栏正常；排除原图黑边、解码失败、栏遮挡/统一扣高。architect已view_image核对修复前/tmp/b5-shell-1280-600-{1,2}.png，四边标记真实存在，单面y0..699而双面y66..633。假设、单变量步骤及真实命令在delivery.md与/tmp/b5-shell-{red,probes}.log。

唯一生产变更为gallery_view.dart移除双面childSize窗口覆盖，让现有PhotoView默认实际outerSize生效，另加说明注释。未改PhotoView库/共享ComicImage、BoxFit、图片文件、用户默认值、缩放策略、配置绑定或主题。

## 独立自动化与分析

代理http/https_proxy=http://127.0.0.1:7897；fvm3.47.7、Flutter全部--no-pub，原生LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib。独立命令：

```
fvm flutter test --no-pub test/features/reader/gallery_viewport_rendering_test.dart test/features/reader/gallery_input_test.dart test/features/reader/dual_page_split_test.dart test/features/reader/page_layout_test.dart test/features/reader/page_navigation_test.dart test/features/reader/continuous_input_test.dart test/features/reader/shell_presentation_test.dart test/features/reader/thumbnails_test.dart test/foundation/reader_preset_binding_test.dart test/foundation/reader_preset_inheritance_test.dart test/foundation/reader_preset_ordering_test.dart --reporter expanded
fvm flutter test --no-pub test/features/reader/gallery_viewport_rendering_test.dart --reporter expanded
fvm flutter analyze --no-pub
```

第一条独立/tmp/b5-architect-related.log为148通过0失败0skip，与executor同集合一致。首次analyze发现新增测试多余dart:async导入，architect明确批准只清理该import，不动断言/生产代码；随后第二条独立/tmp/b5-architect-new-final.log为17通过0失败0skip。17项包含在148项内，不重复相加。

正式像素回归修复前10通过7失败0skip，修复后17全绿。覆盖浅深×左/右/底固定栏×单双面、chrome开关、折叠/浮动对照、ltr/rtl/纵向、800/390/1280 resize、不同尺寸配对/首图单页/横跨页独占/奇数尾页/返回。按实际生产边界与真实RGBA四边标记计算等比contain结果，1.5px亚像素容差不会吞66px错误；未以装饰属性、回调或未解码状态代替最终渲染。

最终独立/tmp/b5-architect-analyze-final.log raw/unique均50=38 tool/code_audit+12其他；与/tmp/b5-analyze-before.log具体集合added=[]、removed=[]，见/tmp/b5-architect-analyze-final-comparison.json。中途51项记录保留，未把新增info当作基线。两既有folder_creation_presentation失败及folder_order_ownership静态基线不在本次局部集合，未称skip或以此吞本次失败。

## GUI 核对与边界

已全文读核/tmp/b5_gui.dart和/tmp/b5_x11.py；初版helper缺坐标边界，未运行，要求修正后再批。最终helper SHA 4ea18b4ae480c8281594223f1ce1a0cfb86ad27dd47dbd2956ef947c1caf4e9d，固定标题/PID/exe/--b5-fixture匹配、键白名单、窗口局部转root及宿主边界、拖动11点预检、按键/鼠标finally释放。harness仅/tmp修正一处括号后SHA e01688d2b2c9e08de67369d0de04edfa6582b34e5118dea4eb989ba8210ecb07，生产main/runner未为fixture修改。

DISPLAY=:1 GDK_BACKEND=x11，本轮/tmp/b5-gui业务/cache/XDG隔离；窗口PID573551、1280×700，宿主1080×760。完整图由RepaintBoundary输出，不冒称完整X11宿主截图。architect逐张view_image核对：

- /tmp/b5-gui/00-startup-full.png和01-single-full.png：浅色双/单，实际viewport1040×700，四边完整、均使用满700高。
- 03-double-full.png：深色双面同样无额外上下留白。
- 04-chrome-full.png、05-light-full.png：深浅chrome随主题，图像几何保持；chrome自身覆盖是原设计，不误判为额外黑带。
- 06-resize800-full.png：800×600现有布局行为、两图完整。
- 08-next/09-next/10-next-full.png：不同比例配对存在各自必要留白、横跨页独占、奇数尾页，未用裁切拉伸抹平比例差异。

各同名前缀json记录window/media/viewport、decoded ready、页码与图像range/scale。n/p为fixture驱动生产导航，不能称GUI验证生产键盘绑定；该保护来自gallery_input等相关回归。真实鼠标double/drag已操作，但fixture缺整页手势宿主、双击scale仍1，不能称已完成GUI缩放验证；保留此局限，不为取得证据改生产代码。受控图不是owner原始漫画输入。

## 构建、清理与冻结

/tmp/b5-main-build.log正常main Linux debug --no-pub构建成功。architect独立strings核对最终kernel含package:venera_next/main.dart，无b5_gui.dart，SHA f01b205384b15c710e94e36e17acbf2f9d993649640ae2808ad1981740b8873b。自身fixture经核对后用q关闭；独立ps -p573551无输出，X11只有qq/Chromium clipboard两个10px窗口。

protected零diff：design-spec.md、openspec/specs/**、pubspec.yaml/lock、正常main/runner、收藏实现/翻译与F10工件未改。git diff --check及openspec validate --changes reader-double-page-letterbox-fix通过，无依赖或新UI文案。

最终源码SHA：gallery_view.dart=bf3a6995ee5716c9ac03ddb7a09f2085ff8945a704b5ee1483dbff41ae7a56f5；gallery_viewport_rendering_test.dart=33325350105627b2c062cea06dd75499cdcd9e35615601ad0fbef2b0895d95d3。测试最终清理import后的复验与以上SHA对应，生产全程仅一处尺寸覆盖删除。已读executor最终delivery，tasks1.x 4/4，/tmp/b5-delivery-sha256.txt四文件全MATCH；最终独立复核结论符合当前修复范围，等待owner人工验收，不授权提交、归档、push或启动其他change。AGENTS/BACKLOG/ROADMAP同步待验收。
