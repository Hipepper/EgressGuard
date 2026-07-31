# EgressGuard 开发记忆

本文记录跨会话仍然有效的实现约束、踩坑结论和发布规范。具体功能实现以源码、测试与提交历史为准。

## SwiftUI 交互与性能

- 不要用包裹全局页面选择状态的 `withAnimation` 驱动侧栏。右侧页面包含材质、阴影和列表时，整棵视图会进入同一动画事务，造成逐帧重绘和明显掉帧。
- 导航选中状态分为两层：侧栏的 `visualSelection` 只负责滑块；内容页状态独立切换。复杂内容切换应采用短促的透明度与轻微位移过渡。
- 侧栏与分段选择器优先使用单一背景图层配合 `offset`，不要为每个选项条件创建背景再使用 `matchedGeometryEffect`。后者在复杂父视图内重建和匹配时容易产生生硬跳动。
- 高频滑块适合高阻尼弹簧；内容区适合约 0.2 秒的 ease-out。动画参数集中放在 `SettingsLayoutMetrics`，避免散落魔法数字。
- 首次进入会立即执行系统命令或 I/O 的页面应延后启动任务，等待导航动画结束；数据刷新写回时关闭隐式动画。
- 主题属于应用偏好，应放在“设置 → 外观”，不要占用一级导航。主题变更通过 `GuardSettings.interfaceTheme` 持久化。

## 本地网络页面

- 页面是只读观察工具，不能修改系统接口、路由或 DNS。
- 接口分类优先使用 macOS 硬件端口元数据，再使用 BSD 名称安全回退。来源无法确定时必须明确标注，不猜测具体 VPN 或代理应用。
- 路由需要区分策略路由、直连路由与邻居缓存；解析器输入输出应由 `LocalNetworkMonitorTests` 覆盖。

## 构建与测试

- 最低系统版本为 macOS 14，Swift 6 严格并发检查开启。
- 提交前至少执行 `swift test` 和 `git diff --check`。
- Codex 受限环境运行 SwiftPM 时，用户级 Clang 缓存可能不可写。使用：

  ```bash
  CLANG_MODULE_CACHE_PATH=/tmp/egressguard-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/egressguard-swiftpm-cache \
  swift test
  ```

- GitHub HTTPS 偶发 `LibreSSL SSL_ERROR_SYSCALL` 时不要改写远端或关闭 TLS 校验；保留本地提交，确认网络后重试。

## 发布规范

- `MARKETING_VERSION` 与 Git 标签保持一致，例如 `1.1.0` 对应 `v1.1.0`；`CURRENT_PROJECT_VERSION` 每次发布递增。
- Release 构建必须包含 arm64 与 x86_64，并在 DMG 制作前验证 `.app` 的版本号、架构与签名状态。
- 临时签名构建必须设置 `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`，避免 Xcode 注入 `get-task-allow` 调试权限。
- 当前机器只有 Apple Development 身份，没有 Developer ID Application 与公证凭据。由此生成的 DMG 可本地安装，但不应宣称已公证。正式外部分发前需补齐 Developer ID 签名、公证和 stapling。
- Release 页面应列出主要变化、系统要求、安装步骤、SHA-256 和签名/公证状态。
- 发布截图放入 `assets/screenshots/`，README 使用仓库相对路径引用。
