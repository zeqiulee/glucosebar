# 维护与发布

## 两种发布状态

当前面向技术测试的是 **未公证技术预览**。源码公开、CI 构建通过、`codesign --verify` 通过，都不意味着另一个 Mac 能直接安装。

面向普通用户的推荐下载，需要 Developer ID Application 身份、hardened runtime、secure timestamp、Apple 公证 Accepted、staple/validate、分发检查，以及另一台 Mac 从网络下载后运行验证。[Apple 分发说明](https://developer.apple.com/macos/distribution/)、[公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## 本地检查

```sh
python3 scripts/check-public-content.py
./scripts/test-core.sh
GLUCOSEBAR_ARCH=universal ./scripts/build-app.sh ./dist
```

`VERSION` 是三段应用版本，`BUILD_NUMBER` 是递增构建号。设置页从 Bundle 读取，勿另外写死。默认 Bundle ID 为 `io.github.zeqiulee.GlucoseBar`，旧钥匙串 service 保留兼容；从个人版迁移前，应验证钥匙串授权和登录项变化。

`GLUCOSEBAR_BUILD_DIR` 可指定编译缓存。`GLUCOSEBAR_ARCH` 支持 `arm64`、`x86_64`、`universal`。不要将跨架构编译成功描述为已在 Intel/Apple Silicon 实机验证。

## 打包技术预览

```sh
GLUCOSEBAR_ARCH=universal \
GLUCOSEBAR_RELEASE_TAG=v0.7.0-beta.1 \
./scripts/package-release.sh ./dist
```

产出带版本、架构及 `unnotarized` 标记的 ZIP 和对应 `.sha256`。Release 说明应包含：测试定位、macOS 14+、架构、未公证、本人账号与设备验证范围、连接门槛、更新内容、已知问题。不要把技术预览称为下载即用正式版。

## 有分发资格后签名公证

先在自己的 Mac 配好 Developer ID Application 证书和 `notarytool` 钥匙串 profile。证书私钥、Apple 凭证、API 私钥及密码不要放在仓库、Issue、聊天或终端历史中；本脚本只引用已有身份和 profile。

```sh
GLUCOSEBAR_ARCH=universal \
GLUCOSEBAR_RELEASE_TAG=v0.7.0-beta.1 \
GLUCOSEBAR_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
GLUCOSEBAR_NOTARY_PROFILE='YOUR_EXISTING_PROFILE' \
./scripts/package-release.sh ./dist
```

脚本只有在公证 Accepted、staple/validate、签名和 `spctl` 检查全部成功后才标记 `notarized`。代码已提供此路径，但还没有用真实 Developer ID / profile 验证；这项仍是发布前待办。

同一版本的签名变化可能影响钥匙串提示。不要覆盖已发布的资产冒充相同文件；修复构建应换版本/标签，并提供新校验和。

## GitHub Actions

- PR 和 `main`：运行公开内容模式检查、合成核心测试，分别交叉构建 arm64/x86_64；默认不接触发布证书。
- `vX.Y.Z` 或 `vX.Y.Z-beta.N`：必须与 VERSION 一致；构建通过后仅创建 **draft prerelease**，不自动公开。
- 在 GitHub 手动运行工作流也能准备草稿：选择 `main`，填写可选的 `release_tag`。留空时只测试和构建；非空且格式、版本匹配时，两架构构建成功后为本次运行的提交创建新标签及草稿预发布。其他分支不能通过此入口创建 Release。
- Actions 构建目前均未公证。正式公证流程在本地完成后，可把经过验证的资产上传到草稿；不要错误混用 signed/unnotarized 资产。
- 第三方 Actions 用版本标签，由 Dependabot 提醒更新；后续可锁定经过核查的提交 SHA。

版本标签命令示例（完成检查与维护者审批后执行）：

```sh
git tag v0.7.0-beta.1
git push origin v0.7.0-beta.1
```

没有配置本地 Git 推送时，可用网页入口：

1. 打开仓库 **Actions → Build GlucoseBar → Run workflow**。
2. 将分支选为 **main**，在 `release_tag` 输入与 VERSION 匹配且尚未使用的标签，例如 `v0.7.0-beta.1`。
3. 点击 Run workflow，等待 arm64 与 x86_64 两个构建、测试和校验和检查全部成功。
4. 到 Releases 查看生成的 **Draft / Pre-release**，核对说明与资产。手动入口只创建草稿，不直接公开。

手动入口将标签指向本次运行的准确提交。为避免资产和已有标签指向不同版本，已存在的标签会被拒绝；需要重做时先检查原运行状态，再选择新的 `beta.N`，不要覆盖已公开版本。通过推送标签触发时则要求标签本来已经存在。

## 公开前人工核对

1. 仓库只含产品源码、文档和合成图片；不含个人健康数据、token、抓包、签名材料或聊天附件。
2. LICENSE 经维护者确认，首页没有未实现或未验证的兼容性承诺。
3. 检查 Release 草稿的标题、系统/架构、公证状态、文件列表和校验和；测试实际下载资产。
4. 在另一台 Mac / 新用户账户上验证：干净安装、退出卸载、演示、首次接入、断网旧数据、恢复与清理失败提示。原 App 告警仍负责提醒。
5. 在 GitHub 开启 Private vulnerability reporting；具体入口参考 [GitHub 官方步骤](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)。
6. 决定公开范围：源码、技术预览或已签名的公开测试版；发布完成后以未登录视角检查首页和公开下载链接。

只有草稿时，其他人看不到下载页；不要提前发送草稿链接。推广与自愿试用步骤见[两周计划](launch-plan.zh-CN.md)。
