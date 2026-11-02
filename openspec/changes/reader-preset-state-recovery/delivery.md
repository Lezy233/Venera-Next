# B3 executor 交付记录

基于修订工件 HEAD `5327e68`。仅执行 reader-preset-state-recovery；B4未启动，未提交。tasks全部完成，等待architect独立复核及提交批准。

## 根因与红灯

真实ReaderPresetSelector应用后Saved和appdata.json中的方案库、边距16断言均通过；销毁重建后期望原ID却得到空字符串。两次稳定复现确认丢失的是组件局部_appliedId身份，不是参数落盘。命令与原证据见diagnosis.md，日志`/tmp/b3-red.log`、`/tmp/b3-red-minimal.log`。原红灯已作为真实组件回归保留并转绿。

## 实现文件

- `lib/foundation/reader_presets.dart`：JSON元组目标身份、持久引用、显式None/目标重置、按实际生效值匹配、设备/目录捕获及恢复入口；保留19键边界及模式override原通道。
- `lib/foundation/appdata.dart`、新增`lib/foundation/settings_recovery.dart`：显式recoveryKey opt-in；在串行writer准入捕获字段存在性，按所有权三方恢复，原目录一次有界补偿所有要求文件；保留初次及补偿错误，目标级持续错误与只恢复不重放的重试。未选择opt-in的设置保存保持原失败行为。
- `lib/features/settings/reader_presets.dart`、`lib/features/settings/reader.dart`：移除局部提示，共用引用恢复；错误重进可见、同目标暂停、恢复按钮及作用域重置联动。
- `lib/components/settings_save_state.dart`：显式控制恢复操作不显示Saved，抑制过期归属成功反馈，允许同域恢复完成后释放原失败注册。
- `assets/translation.json`：新增7组文案，均走.tl并补zh_CN/zh_TW。
- `test/foundation/reader_presets_test.dart`、新增`test/foundation/reader_preset_recovery_test.dart`、`test/features/settings/reader_presets_test.dart`：落盘、身份、匹配、生命周期、真实组件及D4故障矩阵。
- 本change的`tasks.md`及本交付记录。proposal/design/spec未改。

## 自动化验证

实际命令：

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
export LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib
fvm flutter test --no-pub \
  test/foundation/reader_presets_test.dart \
  test/foundation/reader_preset_recovery_test.dart \
  test/foundation/appdata_admission_test.dart \
  test/foundation/appdata_test.dart \
  test/features/settings/reader_presets_test.dart \
  test/features/settings/reader_settings_persistence_test.dart \
  test/features/settings/reader_side_margin_test.dart \
  test/features/reader/quick_settings_panel_test.dart \
  test/components/settings_save_feedback_test.dart \
  test/components/settings_save_host_test.dart
fvm flutter analyze --no-pub
```

结果：10个文件 **108通过、0失败、0skip**；`/tmp/b3-regression-final.log`。
analyze原始 **50**、唯一 **50**，其中tool/code_audit **38**、其余 **12**，零新增；`/tmp/b3-analyze-final.log`。
architect独立复跑同为108通过0skip及50=38+12：`/tmp/b3-architect-regression.log`、`/tmp/b3-architect-analyze.log`。

D4矩阵包含：真实阻断appdata.json.tmp及syncdata.json.tmp的双向一次失败/补偿成功；首次及补偿持续失败、目标暂停、恢复重试不重放；无关键/其他目标/同字段后续接管、同步投影排除规则变更；字段缺省及首次设备身份恢复；None/reset失败；目录切换与回到原归属恢复；D4.4从真实主文件加载而不重放历史操作。组件测试覆盖恢复未完成后销毁重进、无假Saved、解除故障后恢复、明确再次apply，以及排队期间设备切换不派发旧成功效果。

## GUI与实际重启

使用`DISPLAY=:1`、显式X11和隔离XDG（重启fixture由architect启动），业务数据仅`/tmp/b3-gui-data`；临时入口`/tmp/b3_gui.dart`，未改生产main或runner。使用现有`/tmp/search_x11.py`操作明确窗口，按xwininfo确认的1261×1530尺寸抓取。

有效截图均仅留/tmp、不入库：

| 证据 | 路径 |
|---|---|
| 全局应用、销毁重进后仍为Double page | `/tmp/b3-global-applied.png`、`/tmp/b3-global-reentry.png` |
| 设备层未串用全局引用、应用成功、手改动画后显示None | `/tmp/b3-device-before.png`、`/tmp/b3-device-applied.png`、`/tmp/b3-device-mismatch.png` |
| 漫画明确应用 | `/tmp/b3-comic-applied.png` |
| 新进程全局/设备/漫画均恢复Double page | `/tmp/b3-restart-global.png`、`/tmp/b3-restart-device.png`、`/tmp/b3-restart-comic.png` |
| 新进程有界快捷面板恢复同一漫画方案，浅色/深色跟随主题，重建保持引用 | `/tmp/b3-restart-panel-light.png`、`/tmp/b3-restart-panel-dark.png` |

实际进程证据：初始应用PID **119298**（`/tmp/b3-gui-visible-run1.log`及原截图）；重启后PID **241341**（`/tmp/b3-architect-gui-restart.log`及全部restart截图）。新进程启动日志明确加载global/device/comic三个同一方案ID；全局初始截图无历史Saved。设备截图Saved来自截图过程中切设备作用域的新保存，不是历史提示重放。

`/tmp/b3-pre-restart-settings.json`保存重启前磁盘记录，已核对全局/设备/漫画三引用及实际边距16、横向双页2、漫画readerModeOverride=galleryRightToLeft。早前外层滚动宿主导致的空白`/tmp/b3-panel-light.png`、`/tmp/b3-panel-dark.png` **不计通过证据**；已在/tmp入口移除多余外层滚动，以上restart面板图已实际查看通过。

## 生产构建与清理

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
fvm flutter build linux --debug --no-pub -t lib/main.dart
```

成功，日志`/tmp/b3-production-build.log`。正常bundle的kernel_blob.bin检查：包含`package:venera_next/main.dart`，不包含`b3_gui.dart`。`lib/main.dart`、linux runner全程零diff。

指定fixture PID241341已TERM停止并回收；最终ps核对本轮fixture PID111194/113889/119298/241341均已不在进程表。仅保留/tmp中的证据及停止状态的数据目录，无运行fixture，不触碰owner真实库。未加入截图、依赖或lock变更。

最终`git diff --check`通过；`design-spec.md`、`openspec/specs/**`、`pubspec.yaml`、`pubspec.lock`和本change proposal/design/spec零diff。10个实现/测试/翻译文件hash仍与`/tmp/b3-architect-reviewed-files.json`完全一致；独立108/50复核后仅完成GUI/构建和文档收尾，未重复全量测试。

D4.4边界保持：恢复未完成时强退不承诺跨进程耐久回滚或多文件ACID，重启按真实主文件和匹配规则加载，不自动重放、不补历史Saved。
