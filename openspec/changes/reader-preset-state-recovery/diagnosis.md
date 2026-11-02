# B3 executor 诊断记录（HEAD 67dc058）

开工工作区干净。仅执行B3，未提交；生产实现尚未修改。

## 真实组件红灯

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
export LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib
fvm flutter test --no-pub test/features/settings/reader_presets_test.dart --plain-name 'B3 applied preset survives'
```

两次执行均为0通过、1失败、0skip：`/tmp/b3-red.log`、`/tmp/b3-red-minimal.log`。
真实ReaderPresetSelector应用后Saved及当前ID断言通过，appdata.json方案ID与readerSideMargin=16断言通过；组件销毁重建后期望preset.id，实际`''`。第二次最小化去掉JSON重载依赖，单独重建即失败。

测试前排序假设：1.局部身份丢失（仅重建即失败）；2.参数未落盘（检查磁盘）；3.错误作用域读取（固定global排除切层）。磁盘断言排除2，固定global仍失败排除3；局部_appliedId在销毁后丢失，且存储apply只写参数未写身份，确认1。旧行为符合旧归档的临时提示设计，B3要求替换此语义。

## D4真实IO故障实验与待澄清

```sh
# 同上环境；临时探针不入库
fvm flutter test --no-pub /tmp/b3_save_probe_test.dart
```

`/tmp/b3-io-probe.log`：1通过、0失败、0skip。通过将appdata.json.tmp设为目录触发真实FileSystemException：apply报错，磁盘边距仍0，内存已为16，证实appdata先发布draft再持久化的行为。探针仅/tmp，临时数据目录已删除，无运行fixture。

D4要求处理参数及引用、不得假成功、保留并发无关设置，但未明确失败后参数恢复旧值还是保留已发布值并使新引用失效；也未明确appdata.json成功而syncdata.json失败时的耐久补偿边界。两种结果会改变可观察行为与回归断言。按owner明确要求，停止1.2–1.4实现并报告architect，请修订工件明确后续行为；executor不自行选择失败回滚契约。

未进入实现与最终验证；analyze、GUI、生产构建尚未执行。main.dart未改，protected文件零改动。
