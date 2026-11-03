## 1. 实现与证据（逐项完成立即勾选并备注）

- [x] 1.1 核对HEAD/干净工作区、最小阅读；以生产SearchPage建立重开丢失的红灯，并记录实际控件与路由参数断言；记录保护文件SHA。HEAD cb1e328，工作区干净；/tmp/f8-protected-start.sha256；search_target_memory_test.dart 真实点击B重开后路由期望b实际a，0通过1失败，/tmp/f8-red.log。
- [x] 1.2 实现带版本搜索选择解析与局部持久化；覆盖旧数据/明确null/坏值、默认隔离、可靠写入/失败补偿/目录归属及快速选择。search_selection.dart复用独立recoveryKey；真实appdata/syncdata故障、补偿、恢复、目录排队归属及保存期间禁用测试通过，/tmp/f8-regression.log。
- [x] 1.3 接入真实搜索页控件与动态来源/方案解析；完成失效可见回退、空来源防护、双语及真实路由恰好一次测试，保持临时options和显式搜索入口语义。生产控件重开、profileId/sourceKey/options和请求次数、动态失效恢复、历史点击与临时options回归通过；zh_CN/zh_TW已补；搜索/F6/F7合计50通过0skip（待最终扩展及analyze）。
- [x] 1.4 完成design D5真实回归矩阵、相关搜索/F6/F7回归、analyze raw/unique50=38+12零新增；记录命令、通过/skip计数和保护零diff/diff-check。最终59通过（F8新增25+相关34）、0skip；/tmp/f8-regression-final.log。analyze raw/unique50=38+12，/tmp/f8-analyze-final.log；81个保护文件SHA一致，translation.json仅追加两语言各5条、旧词条全部未变；git diff --check通过。详见review.md。
- [x] 1.5 隔离GUI验证两宽度/主题/键盘/聚合与单源及真实进程重启；正常main构建、清理fixture，提交交付说明与/tmp截图路径，等待architect独立复核，不自行提交/归档/push。1280 expanded与600 compact、浅深主题、键盘Enter、聚合p与单源B/null；PID559166→565588聚合恢复、565588→568402单源恢复，实际路由/请求各一次，审计/tmp/f8-gui-audit.jsonl。截图逐张核对，见review.md；正常main构建/tmp/f8-main-build.log成功；4个本轮PID与X11窗口已清理。交付未提交，待architect复核。
