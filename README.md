<h4 align="right">
  <strong>简体中文</strong> | <a href="README_en.md">English</a> | <a href="README_ru.md">Русский</a>
</h4>

<h1 align="center">⚡ Bettbox</h1>
<p align="center">
  <strong>Another Better Mihomo Client</strong>
</p>

**Bettbox 是一款使用Mihomo(Clash Meta)内核、基于FlClash早期版本进行重构的多平台代理客户端**

秉承“Better Experience更优体验”的原则，Bettbox在继承原版优秀界面的基础上，深度优化了诸多细节与实用功能/逻辑。设计目标: 前台流畅丝滑、后台省电无感，致力于成为体验更好、可长期稳定运行的 Mihomo 客户端

**内核当前支持协议**：Shadowsocks ( R / 2022 / ShadowTLS / Restls )、Trojan、VMess、VLESS ( XHTTP / Reality )、Hysteria ( v1 / v2 )、TUIC、WireGuard、Tailscale、OpenVPN、SSH、AnyTLS、Mieru、Snell ( v1-v5 )、Masque、TrustTunnel、Sudoku、Gost-relay 以及 HTTP/Socks5 等。

Bettbox意为: Better Experience, Out of the box，卓越体验，亦开箱可用

[![Latest Release](https://img.shields.io/github/v/release/appshubcc/Bettbox?style=for-the-badge&logo=github&color=238636&label=Release)](https://github.com/appshubcc/Bettbox/releases/latest) [![Core](https://img.shields.io/github/v/release/MetaCubeX/mihomo?style=for-the-badge&logo=go&logoColor=white&color=8A2BE2&label=Mihomo)](https://github.com/MetaCubeX/mihomo/releases/latest) [![Downloads](https://img.shields.io/github/downloads/appshubcc/Bettbox/total?style=for-the-badge&logo=github&color=007ec6)](https://github.com/appshubcc/Bettbox/releases) 
---
### ✈️ Telegram 社区交流

</div>

<div align="left">

[![Telegram Group](https://img.shields.io/badge/Appshub-Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_chat) [![Telegram Channel](https://img.shields.io/badge/Appshub-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_channel)

---
###   🛩️ 推荐链接
### [良心云](https://xn--9kqz23b19z.com/#/register?code=VTnrQYAj)  〢  [一分机场](https://xn--4gqx1hgtfdmt.com/#/register?code=AuCiXprV)  〢  [赔钱机场](https://xn--mes358aby2apfg.com/register?code=z7TUZLmM&cover=sfw)

**简评** : ❚ 相对性价比较高，20元/1000GB/永久套餐值得推荐，群友反馈口碑尚可; 需要注意: 机场服务与Bettbox软件无直接关联，最终效果请自行判定

### ☕ 赞助支持

**如果您觉得这个项目对您有所帮助，可以通过以下方式赞助开发或使用上方的推荐链接：**

* TRON (TRC-20)：   <code>TCkTtZfF2WrciZLaJj3e1aqrh3zdTnCkDa</code>
* EVM Compatible：  <code>0xF8B1B39431013359D83F38a4e403087624618E67</code>
* Solana：  <code>C2YQPcKR2YmrPtBvkE13wckjgescUfMA5HzUioR4rQUd</code>
* Bitcoin： <code>bc1qu950cl6035qvllmzk6cfw3l30j2lg3cq9n6g6h</code>

---

## 🛠️ 安装与下载

请前往 **[[Releases]](https://github.com/appshubcc/Bettbox/releases)** 页面下载最新适合您平台和系统的安装包

其他安装方式:</br>
**ArchLinux:** <code>yay -S bettbox-bin 或 paru -S bettbox-bin</code>

* **主流桌面端**: **Windows** (x64/arm64), **macOS** (Intel/Apple Silicon), **Linux** (x64/arm64)
* **Windows7**: 请配合 [[VxKex]](https://github.com/i486/VxKex/releases) 使用
* **Android平台**: **Android** (ARMv8/ ARMv7/ x86_64/ Universal) 
* **Android TV**: 已完整适配,可选ARMv7 32位
* **鸿蒙NEXT**: 请配合 [[卓易通]](https://harmonyos.cool/android-app) 使用

---
</div>

## 🚀 核心特性

* **开箱即用**：稳定的权限处理与舒适的 TUN/VPN 体验，大量预置优化与细节，开箱即达可用状态。
* **精雕细琢**：打磨每处 UI 与功能交互细节，前台高帧率动画流畅，移动端低能耗，桌面端低占用。
* **安全守护**：内核紧跟 Mihomo 主线分支且积极适配最新特性，多平台保持严格的权限控制与校验。
* **稳定容错**：优化多平台极端场景下的稳定性，内置YAML格式验证和提前预解析双重错误检测机制。
* **性能优先**：桌面端原生 ARM64 架构支持，提供硬件分级和 Flutter 整体优化, 充分发挥硬件性能。
* **增强工具**：支持多平台无感智能启停、Android端休眠支持、一键禁用QUIC、托盘菜单增强等等。
* **可视化设置**：提供丰富参数的可视化调节界面，支持改动即时生效，无需繁琐修改配置。
* **首页小组件**：内置多款精致 Widget 小组件，在首页直观掌控实时网速与全局运行状态。
* **个性化定制**：支持丰富色彩主题、自定义图标/标题等，甚至还包含 10 种精美测速动画。
* **设备兼容**：持续维护面向旧版系统及老旧硬件的 Compatible 兼容版本，延长设备使用周期。
* **零隐私风险**：开源、无广告，全透明的 CI/CD 流程且接受全方位审计，杜绝后台隐私收集。
* **社区导向**：我们会认真评估社区反馈，优先对待高质量的 Issue，你的声音不会无故被淹没。

---

##  常见问题

1. 安装后无法启动？
   - 安卓端旧设备，请检查**是否满足Bettbox的最低系统要求**:Android 8.0+
   - 桌面端旧设备，请检查**是否需要下载特定CPU等级的Compatible兼容版本**
   - 其他问题如持续存在，请提交ISSUE反馈

2. 桌面端常见问题
   - Windows管理员权限：Bettbox在安装时已提前处理，**无需手动再次授权**
   - 无法开启TUN虚拟网卡：macOS和Linux**请确保输入正确密码给与权限授权**
   - 其他报错：请提供Debug信息，并**确保没有冲突的代理软件或服务正在运行**
   - 其他问题如持续存在，请提交ISSUE反馈

3. 无法导入订阅链接
   - **请务必先尝试重置链接，确保链接正常后再导入**
   - **确保导入的是Clash（Mihomo）格式的订阅链接**
   - 其他问题如持续存在，请提交ISSUE反馈

4. 待持续完善补充..

---

##  开发构建

以Windows为例：

* 你需要一台Windows设备（≥Windows 10）
* 必要的软件依赖：Visual Studio，Flutter SDK≥3.44，Golang，Inno Setup，Rust
* dart .\setup.dart windows --arch amd64 --compatible(可选兼容版本)

---

##  致谢

Bettbox 的诞生依赖以下根基项目：

* [FlClash](https://github.com/chen08209/FlClash) - 来自陈师傅的优秀开源GUI
* [Mihomo](https://github.com/MetaCubeX/mihomo) - 强大/灵活/稳定的代理内核

开发构建过程中还额外从以下开源项目获取过灵感(以参考顺序排名)：

[CMFA](https://github.com/MetaCubeX/ClashMetaForAndroid), [Sparkle](https://github.com/xishang0128/sparkle), [SFA](https://github.com/SagerNet/sing-box-for-android), [HUSI](https://github.com/xchacha20-poly1305/husi), [V2rayN](https://github.com/2dust/v2rayN)

---

## 📄 开源协议

GPL-3.0 license 开源协议