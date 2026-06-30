<h4 align="right">
  <a href="README.md">简体中文</a> | <strong>English</strong> | <a href="README_ru.md">Русский</a>
</h4>

<h1 align="center">⚡ Bettbox</h1>
<p align="center">
  <strong>Another Better Mihomo Client</strong>
</p>

Bettbox is a multi-platform proxy client based on an early version of FlClash, refactored and powered by the Mihomo (Clash Meta) core.

Following the principle of "Better Experience", Bettbox inherits the excellent user interface of the original project while deeply optimizing numerous details and internal logic. It aims to be a Mihomo client that delivers a smooth frontend experience, silent and power-efficient background operation, and long-term stability.

**Supported Core Protocols**: Shadowsocks ( R / 2022 ), Trojan, VMess, VLESS ( XHTTP / Reality ), Hysteria ( v1 / v2 ), TUIC, WireGuard, Tailscale, OpenVPN, SSH, AnyTLS, Mieru, Snell ( v1-v5 ), Masque, TrustTunnel, Sudoku, Gost-relay, as well as standard HTTP/Socks5, etc.

Bettbox stands for: Better Experience, Out of the box.

[![Latest Release](https://img.shields.io/github/v/release/appshubcc/Bettbox?style=for-the-badge&logo=github&color=238636&label=Release)](https://github.com/appshubcc/Bettbox/releases/latest) [![Core](https://img.shields.io/github/v/release/MetaCubeX/mihomo?style=for-the-badge&logo=go&logoColor=white&color=8A2BE2&label=Mihomo)](https://github.com/MetaCubeX/mihomo/releases/latest) [![Downloads](https://img.shields.io/github/downloads/appshubcc/Bettbox/total?style=for-the-badge&logo=github&color=007ec6)](https://github.com/appshubcc/Bettbox/releases) 

---

## Recommended Services
### Cost-Effective: [LiangXinYun](https://xn--9kqz23b19z.com/#/register?code=VTnrQYAj)   〢   [YiFenJiChang](https://xn--4gqx1hgtfdmt.com/#/register?code=AuCiXprV)

**Brief Review**: ❚ ❚ Highly cost-effective starting at ¥2. Offers ¥6/1000GB per month or ¥21/1000GB for permanent bandwidth. Supports AI tools and partial streaming media unlock. Well-received by the community. Note: This is an independent affiliate recommendation. The service is not directly affiliated with the Bettbox software. Please use at your own discretion.

---


## 🛠️ Installation

Please visit the [Releases](https://github.com/appshubcc/Bettbox/releases) page to download the latest installer for your system.

**Other Installation Methods:**
- ArchLinux: `yay -S bettbox-bin` or `paru -S bettbox-bin`

* **Desktop**: Windows (x64/arm64), macOS (Intel/Apple Silicon), Linux (x64/arm64)
* **Windows 7**: Please use in conjunction with [[VxKex]](https://github.com/i486/VxKex/releases).
* **Android**: ARMv8 / ARMv7 / x86_64 / Universal
* **Android TV**: Supported (ARMv7 32-bit recommended).
* **HarmonyOS NEXT**: Please use in conjunction with [[ZhuoYiTong]](https://harmonyos.cool/android-app).

---
### ✈️ Telegram Community

</div>

<div align="left">

[![Telegram Group](https://img.shields.io/badge/Appshub-Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_chat) [![Telegram Channel](https://img.shields.io/badge/Appshub-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_channel)

---
</div>

## 🚀 Core Features

### Enhanced User Experience
* **Out of the box**: Stable permission handling and seamless TUN/VPN integration. Pre-configured with optimized parameters instead of default examples, ensuring a usable state out of the box.
* **Refined UI**: Carefully polished interface and interactions. Operates lightly in the background, ensuring low battery consumption on mobile devices and minimal CPU footprint on desktops.

### Security and Stability
* **Security Guardian**: The core engine closely tracks the Mihomo mainline, rapidly adopting new features while enforcing strict cross-platform permission controls.
* **Resilience**: Optimized for extreme network scenarios. Features an elegant fallback mechanism for configuration errors to ensure continuous, reliable service.

### Flexible Customization
* **Visual Settings**: Offers comprehensive UI-based settings. Supports immediate effect of changes without the need for manual configuration file editing.
* **Dashboard Widgets**: Includes built-in widgets that allow you to intuitively monitor real-time network speeds and operational status directly from the home screen.
* **Personalization**: Supports multiple color themes, custom icons, and 10 dynamic network speed test animations.

### Performance and Compatibility
* **Performance First**: Native support for desktop ARM64. Implements CPU hardware grading and overall Flutter communication/response performance optimizations.
* **Broad Compatibility**: Actively maintains "Compatible" builds tailored for legacy hardware and older operating systems to extend device lifecycles.
* **Community-Driven**: We prioritize high-quality issues and actively incorporate community feedback.

### Open Source and Transparent
* **Automated Builds**: Fully transparent CI/CD pipeline powered by GitHub Actions. What you see in the code is exactly what you get in the release.
* **Zero Privacy Risk**: Completely free and ad-free. The source code is open to public auditing, strictly prohibiting any background telemetry or data collection.

---

## ❓ FAQ

1. **Cannot launch after installation?**
   - For older Android devices, verify that your system meets the minimum requirement (Android 8.0+).
   - For older desktop devices, ensure you have downloaded the appropriate "Compatible" version for your CPU architecture.
   - If the issue persists, please open an Issue.

2. **Common Desktop Issues**
   - **Windows Administrator Privileges**: Handled automatically during installation; no manual authorization is required afterward.
   - **Unable to start TUN adapter**: On macOS and Linux, ensure you enter the correct administrator password when prompted.
   - **Other errors**: Please provide runtime logs and verify that no conflicting proxy software is running simultaneously.

3. **Unable to import subscription links**
   - Attempt to reset or refresh the subscription link in your browser first to ensure it is active.
   - Verify that the link is formatted for Clash (Mihomo).

4. **To be continued...**

---

## 💻 Development

Example for Windows:

* Requires a Windows environment (≥ Windows 10)
* Dependencies: Visual Studio, Flutter SDK ≥ 3.44, Golang, Inno Setup, Rust
* Build command: `dart .\setup.dart windows --arch amd64 --compatible` (the `--compatible` flag is optional)

---

## ❤️ Acknowledgements

Bettbox is built upon the following foundational projects:

* [FlClash](https://github.com/chen08209/FlClash) - An excellent open-source GUI by developer Chen.
* [Mihomo](https://github.com/MetaCubeX/mihomo) - A powerful, flexible, and robust proxy core.

We also drew inspiration from the following open-source projects during development (listed in order of reference):

[CMFA](https://github.com/MetaCubeX/ClashMetaForAndroid), [Sparkle](https://github.com/xishang0128/sparkle), [SFA](https://github.com/SagerNet/sing-box-for-android), [HUSI](https://github.com/xchacha20-poly1305/husi), [V2rayN](https://github.com/2dust/v2rayN)

---

## 📄 License

Licensed under the GPL-3.0 License.
