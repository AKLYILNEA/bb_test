<h4 align="right">
  <a href="README.md">简体中文</a> | <strong>English</strong> | <a href="README_ru.md">Русский</a>
</h4>

<h1 align="center">⚡ Bettbox</h1>
<p align="center">
  <strong>Another Better Mihomo Client</strong>
</p>

**Bettbox is a multi-platform proxy client based on an early version of FlClash, refactored and powered by the Mihomo (Clash Meta) core.**

Following the principle of "Better Experience", Bettbox inherits the excellent user interface of the original project while deeply optimizing numerous details and internal logic. It aims to be a Mihomo client that delivers a smooth frontend experience, silent and power-efficient background operation, and long-term stability.

**Supported Core Protocols**: Shadowsocks ( R / 2022 / ShadowTLS / Restls ), Trojan, VMess, VLESS ( XHTTP / Reality ), Hysteria ( v1 / v2 ), TUIC, WireGuard, Tailscale, OpenVPN, SSH, AnyTLS, Mieru, Snell ( v1-v5 ), Masque, TrustTunnel, Sudoku, Gost-relay, as well as standard HTTP/Socks5, etc.

Bettbox stands for: Better Experience, Out of the box.

[![Latest Release](https://img.shields.io/github/v/release/appshubcc/Bettbox?style=for-the-badge&logo=github&color=238636&label=Release)](https://github.com/appshubcc/Bettbox/releases/latest) [![Core](https://img.shields.io/github/v/release/MetaCubeX/mihomo?style=for-the-badge&logo=go&logoColor=white&color=8A2BE2&label=Mihomo)](https://github.com/MetaCubeX/mihomo/releases/latest) [![Downloads](https://img.shields.io/github/downloads/appshubcc/Bettbox/total?style=for-the-badge&logo=github&color=007ec6)](https://github.com/appshubcc/Bettbox/releases) 
---
### ✈️ Telegram Community

</div>

<div align="left">

[![Telegram Group](https://img.shields.io/badge/Appshub-Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_chat) [![Telegram Channel](https://img.shields.io/badge/Appshub-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/appshub_channel)

---

### ☕ Sponsorship

**If you find this project helpful, you can sponsor the development through the following methods:**

* TRON (TRC-20): <code>TCkTtZfF2WrciZLaJj3e1aqrh3zdTnCkDa</code>
* EVM Compatible: <code>0xF8B1B39431013359D83F38a4e403087624618E67</code>
* Solana: <code>C2YQPcKR2YmrPtBvkE13wckjgescUfMA5HzUioR4rQUd</code>
* Bitcoin: <code>bc1qu950cl6035qvllmzk6cfw3l30j2lg3cq9n6g6h</code>

---


## 🛠️ Installation

Please visit the [Releases](https://github.com/appshubcc/Bettbox/releases) page to download the latest installer for your system.

**Other Installation Methods:**</br>
**ArchLinux:** <code>yay -S bettbox-bin or paru -S bettbox-bin</code>

* **Mainstream Desktop**: **Windows** (x64/arm64), **macOS** (Intel/Apple Silicon), **Linux** (x64/arm64)
* **Windows 7**: Please use in conjunction with [[VxKex]](https://github.com/i486/VxKex/releases).
* **Android**: **Android** (ARMv8/ ARMv7/ x86_64/ Universal)
* **Android TV**: Fully supported, ARMv7 32-bit optional
* **HarmonyOS NEXT**: Please use in conjunction with [[ZhuoYiTong]](https://harmonyos.cool/android-app).

---
</div>

## 🚀 Core Features

* **Out of the box**: Stable permission handling and seamless TUN/VPN integration. Pre-configured with plenty of optimizations and details, ensuring a usable state right out of the box.
* **Refined UI**: Carefully polished interface and functional interactions. Smooth high-framerate frontend animations, low energy consumption on mobile devices, and minimal CPU footprint on desktops.
* **Security Guardian**: The core engine closely tracks the Mihomo mainline branch and actively adapts to the latest features, maintaining strict cross-platform permission controls and verifications.
* **Resilience**: Optimized stability under multi-platform extreme scenarios. Built-in dual error detection mechanism with YAML format validation and early pre-parsing.
* **Performance First**: Native support for multi-platform ARM64 architecture. Implements hardware grading and overall Flutter optimization, fully utilizing hardware performance.
* **Enhanced Tools**: Supports seamless smart start/stop across platforms, Android sleep mode support, one-click QUIC disable, system tray menu enhancements, and more.
* **Visual Settings**: Offers comprehensive UI-based settings. Supports immediate effect of changes without the need for manual configuration file editing.
* **Dashboard Widgets**: Includes built-in widgets that allow you to intuitively monitor real-time network speeds and operational status directly from the home screen.
* **Personalization**: Supports multiple color themes, custom icons/titles, and even includes 10 beautiful dynamic network speed test animations.
* **Broad Compatibility**: Actively maintains "Compatible" builds tailored for legacy hardware and older operating systems to extend device lifecycles.
* **Zero Privacy Risk**: Open source, ad-free. Fully transparent CI/CD pipeline and open to public auditing, strictly prohibiting any background telemetry or data collection.
* **Community-Driven**: We carefully evaluate community feedback and prioritize high-quality issues, your voice won't be drowned out.

---

## ❓ FAQ

1. **Cannot launch after installation?**
   - For older Android devices, please verify **if it meets Bettbox's minimum system requirements**: Android 8.0+
   - For older desktop devices, please verify **if you need to download a specific CPU grade Compatible version**
   - If the issue persists, please open an Issue.

2. **Common Desktop Issues**
   - Windows Administrator Privileges: Handled automatically during installation, **no manual authorization is required afterward**.
   - Unable to start TUN adapter: On macOS and Linux, **please ensure you enter the correct password to grant permissions**.
   - Other errors: Please provide Debug info, and **ensure no conflicting proxy software or services are running**.
   - If the issue persists, please open an Issue.

3. **Unable to import subscription links**
   - **Please make sure to try resetting the link first to ensure it's active before importing.**
   - **Ensure that the imported link is in Clash (Mihomo) format.**
   - If the issue persists, please open an Issue.

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

* [FlClash](https://github.com/chen08209/FlClash) - An excellent open-source GUI by master Chen.
* [Mihomo](https://github.com/MetaCubeX/mihomo) - A powerful, flexible, and robust proxy core.

We also drew inspiration from the following open-source projects during development (listed in order of reference):

[CMFA](https://github.com/MetaCubeX/ClashMetaForAndroid), [Sparkle](https://github.com/xishang0128/sparkle), [SFA](https://github.com/SagerNet/sing-box-for-android), [HUSI](https://github.com/xchacha20-poly1305/husi), [V2rayN](https://github.com/2dust/v2rayN)

---

## 📄 License

Licensed under the GPL-3.0 License.
