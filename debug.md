# Debug Session: 2026-02-23-001
- **Status**: [OPEN]
- **Issue**: 前台应用焦点变化无法准确监听，输入法切换未触发

## Reproduction Steps (Repro Steps)
1. 确保调试服务器运行在 `http://127.0.0.1:7777/event`
2. 在项目根目录运行 `swift run --disable-sandbox`
3. 启动后 30 秒内切换前台应用（例如 VSCode → 飞书 → 微信）
4. 记录 `.dbg/trae-debug-log-<sessionId>.ndjson` 中 runId 为 `pre-fix` 的日志

## Hypotheses & Verification (Hypotheses)
- [x] Hypothesis A: didActivateApplication 通知未触发或触发频率异常 | Evidence: Rejected（日志中已出现多条 did_activate_application）
- [ ] Hypothesis B: 前台应用 bundleId 与配置不匹配导致无法命中映射 | Evidence: Pending
- [x] Hypothesis C: 前台应用确实变化，但应用未激活导致通知丢失 | Evidence: Rejected（非本应用 bundleId 也被记录）
- [ ] Hypothesis D: 输入法切换调用执行但未成功切换 | Evidence: Pending

## Verification Conclusion (Verification)
[Pending]
