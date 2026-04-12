<h1 align="center">⚡ Bettbox</h1>
<p align="center">
  <strong>Another Better Mihomo Client</strong>
</p>

Bettbox 是一款使用Mihomo(Clash Meta)内核、基于FlClash早期版本进行重构的多平台代理客户端

秉承“Better Experience更优体验”的原则，Bettbox在继承原版优秀界面的基础上，深度优化了诸多细节与实用功能/逻辑。前台流畅丝滑、后台省电无感，致力于成为体验更好且可长期稳定运行的 Mihomo 客户端

Bettbox意为: Better Experience, Out of the box，卓越体验，亦可开箱即用

[![Latest Release](https://img.shields.io/github/v/release/appshubcc/Bettbox?style=for-the-badge&logo=github&color=238636&label=Release)](https://github.com/appshubcc/Bettbox/releases/latest) [![Core](https://img.shields.io/github/v/release/MetaCubeX/mihomo?style=for-the-badge&logo=go&logoColor=white&color=8A2BE2&label=Mihomo)](https://github.com/MetaCubeX/mihomo/releases/latest) [![Downloads](https://img.shields.io/github/downloads/appshubcc/Bettbox/total?style=for-the-badge&logo=github&color=007ec6)](https://github.com/appshubcc/Bettbox/releases) 

---



## 🛠️ 安装与下载

请前往 [Releases](https://github.com/appshubcc/Bettbox/releases) 页面下载最新适合您平台和系统的安装包

* **桌面端**: Windows (x64/arm64), macOS (Intel/Apple Silicon), Linux (x64/arm64)
* **安卓端**: Android (ARMv8/ ARMv7/ x86_64/ Universal) 
* **Android TV**: 已支持,可选ARMv7 32位
* **Windows7**: 请配合 [[VxKex]](https://github.com/i486/VxKex/releases) 使用
* **鸿蒙NEXT**: 请配合 [[卓易通]](https://harmonyos.cool/android-app) 使用

---
### ✈️ Telegram 社区交流

</div>

<div align="left">

[![Telegram Group](https://img.shields.io/badge/Appshub-Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_chat) [![Telegram Channel](https://img.shields.io/badge/Appshub-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_channel)

---
</div>

## 🚀 核心特性

###  深度体验优化
* **开箱即用**：自动化的权限处理与舒适稳定的TUN&VPN体验，预置更加适合中国大陆用户的内核配置，减少繁琐的手动调试/配置多为可选项
* **精雕细琢**：重新审视打磨每一处功能细节，稳定无感的轻量模式，移动端更加省电、桌面端更低占用、旨在提供更好的Mihomo客户端体验

###  安全与稳定性
* **安全校验**：遵循Mihomo官方安全建议/内核升级紧跟主线版本，桌面端拥有严格的安全校验以及权限控制，有效防范潜在的TOCTOU或非法访问，同时针对常见配置错误增加了优雅的回退机制
* **高稳定性**：通过了作者自身和群友长期以来高强度的压力测试与后台使用测试，优化了多处极端场景下的使用稳定性问题

###  自由可定制化
* **可视化管理**：更加全面且易用的功能配置界面，支持更多参数的可视化操作调整和实时生效
* **实用小组件**：提供多种美观实用风格的 Widgets，在首页可以掌控全局流量和当前运行状态
* **个性化定制**：丰富的预置色彩主题、自定义图标/首页标题，多个界面布局调整，甚至连Urltest都有10种精美动画可供选择，每个人都可以拥有自己独一无二的Bettbox

###  多个平台支持
* **性能优先级**：支持主流架构，为现代设备额外优化的CPU性能(例如桌面端分级和Android 16K对齐)，针对多平台桌面端 ARM64 设备同样提供了原生适配
* **社区包容性**：我们倾听社区用户的想法并且会认真评估，你的声音不会无故被淹没和被无视(认真的ISSUE会被优先对待)
* **旧设备关怀**：尽力而为提供针对旧版本系统和硬件的兼容性版本，确保长周期的使用寿命

###  开源纯净透明
* **全自动 CI/CD**：基于 GitHub Actions 的透明构建流程，代码即产物，所见即所得
* **纯净无广告**：免费，且完全开源，代码接受全方位审计，无需担心额外的隐私问题

---

##  常见问题

1. 安装后无法启动？
   - 安卓端旧设备，请检查是否支持Bettbox的最低系统要求:Android 8.0+
   - 桌面端旧设备，请检查是否需要下载特定CPU等级的Compatible兼容版本
   - 其他问题如持续存在，请提交ISSUE反馈

2. Windows常见问题
   - 管理员权限：Bettbox在安装时已提前处理，无需手动再次授权
   - 无法开启虚拟网卡：请确保没有冲突的代理软件或服务正在运行
   - 无法同时开启系统代理和虚拟网卡：预期行为（如果明确自己的需求，则可以通过系统托盘区同时开启）
   - 其他问题如持续存在，请提交ISSUE反馈

3. 无法导入订阅链接
   - 请务必先尝试重置链接，确保链接正常后再导入
   - 确保导入的是Clash（Mihomo）格式的订阅链接
   - 其他问题如持续存在，请提交ISSUE反馈

4. 待持续完善和补充..

---

##  开发构建

以Windows为例：

* 你需要一台Windows设备（≥Windows 10）
* 必要的软件依赖：Visual Studio，Flutter SDK≥3.35，Golang，Inno Setup，Rust
* dart .\setup.dart windows --arch amd64 --compatible(可选兼容版本)

---

##  赞助链接

* **暂无**:  所有功能均免费无广告，您可以点击右上角的⭐Star，让开发者获得认同感也是一种支持方式

---

##  致谢

Bettbox 的诞生依赖以下根基项目：

* [FlClash](https://github.com/chen08209/FlClash) - 来自陈师傅的优秀开源项目
* [Mihomo](https://github.com/MetaCubeX/mihomo) - 强大灵活稳定的代理内核

开发构建过程中还额外从以下开源项目获取过灵感(以参考顺序排名)：

[CMFA](https://github.com/MetaCubeX/ClashMetaForAndroid), [Sparkle](https://github.com/xishang0128/sparkle), [SFA](https://github.com/SagerNet/sing-box-for-android), [HUSI](https://github.com/xchacha20-poly1305/husi), [V2rayN](https://github.com/2dust/v2rayN)

---

## 📄 开源协议

延续原项目 GPL-3.0 license 开源协议
