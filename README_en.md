<h4 align="right">
  <a href="README.md">简体中文</a> | <strong>English</strong> | <a href="README_ru.md">Русский</a> | <a href="README_fa.md">فارسی</a> | <a href="README_ja.md">日本語</a> | <a href="README_ko.md">한국어</a>
</h4>

<h1 align="center">⚡ Bettbox</h1>
<p align="center">
  <strong>Another Better Mihomo Client</strong>
</p>

**Bettbox is a multi-platform network debugging and traffic splitting client based on an early version of FlClash, refactored and powered by the Mihomo (Clash Meta) core.**

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


* **All Desktop Platforms**: **Windows** (x64/arm64), **macOS** (Intel/Apple Silicon), **Linux** (x64/arm64)
* **Android Devices**: Android (ARMv8/ ARMv7/ x86_64/ Universal)
* **Android TV**: Fully supported, ARMv7 32-bit optional
* **HarmonyOS NEXT**: Please use in conjunction with [[ZhuoYiTong]](https://harmonyos.cool/android-app).

**Other Installation Methods:**<br>
**ArchLinux:** <code>yay -S bettbox-bin or paru -S bettbox-bin</code><br>
**AMD64=v1:** <code>yay -S bettbox-compatible-bin or paru -S bettbox-compatible-bin</code>

---
</div>

## 🚀 Core Features

* **Out of the box**: Stable permission handling and seamless TUN/VPN integration. Pre-configured with plenty of optimizations and details, ensuring a usable state right out of the box.
* **Refined UI**: Carefully polished interface and functional interactions. Smooth high-framerate frontend animations, low energy consumption on mobile devices, and minimal CPU footprint on desktops.
* **Security Guardian**: The core engine closely tracks the Mihomo mainline branch and actively adapts to the latest features, maintaining strict cross-platform permission controls and verifications.
* **Resilience**: Optimized stability under multi-platform extreme scenarios. Built-in dual error detection mechanism with YAML format validation and early pre-parsing.
* **Performance First**: Native support for multi-platform ARM64 architecture. Implements hardware grading and overall Flutter optimization, fully utilizing hardware performance.
* **Enhanced Tools**: First multi-platform seamless smart start/stop, Android sleep mode support, one-click QUIC disable, system tray menu enhancements, and more.
* **Visual Settings**: Offers comprehensive UI-based settings. Supports immediate effect of changes without the need for manual configuration file editing.
* **Dashboard Widgets**: Includes built-in widgets that allow you to intuitively monitor real-time network speeds and operational status directly from the home screen.
* **Personalization**: Supports multiple color themes, custom icons/titles, and even includes 10 beautiful dynamic network speed test animations.
* **Broad Compatibility**: Actively maintains "Compatible" builds tailored for legacy hardware and older operating systems to extend device lifecycles.
* **Zero Privacy Risk**: Open source, ad-free. Fully transparent CI/CD pipeline and open to public auditing, strictly prohibiting any background telemetry or data collection.
* **Community-Driven**: We carefully evaluate community feedback and prioritize high-quality issues, your voice won't be drowned out.

---

## ❓ FAQ

1. **Installation, Startup and Security:**
   - For Android devices, please check **if sufficient background permissions are granted and if it meets the minimum system requirements**: Android 8.0+
   - For older desktop devices, please check the system platform architecture **to see if you need to download a specific CPU grade Compatible version**
   - **Security: The Bettbox project is completely open source and transparent. The current codebase has passed security auditing by the Signpath Foundation.**

2. **Common Desktop Issues:**
   - Windows Administrator Privileges: Handled automatically during installation, **no manual authorization is required afterward**.
   - Unable to start TUN adapter: On macOS and Linux, **please ensure you enter the correct password to grant permissions**.
   - Other errors: Please provide Debug info, and **ensure no conflicting proxy software or services are running**.
   - If the issue persists, please open an Issue.

3. **macOS Installation Guide:**
   - After downloading the version matching your platform (Intel/Apple Silicon), double-click to open the Bettbox-macos-xx.dmg file.
   - Drag the Bettbox icon into the Applications folder to complete the installation.
   - **Bypass Gatekeeper security blocks for first launch** (since we currently do not purchase Apple developer certificates):
     - **Recommended**: Open the "Applications" folder, **right-click the Bettbox icon**, select **"Open"**, then click **"Open"** again in the confirmation dialog.
     - **Alternative**: If double-clicking is blocked, go to Mac "System Settings" -> "Privacy & Security", find Bettbox and click **"Open Anyway"**.
   - The first time you enable TUN mode, the system will prompt you for password authentication. Please enter your Mac user password to allow Bettbox to configure the network.
   - **If it says "is damaged and can't be opened, you should move it to the Trash":**
     - This is a false positive of macOS Gatekeeper for unsigned software. Open Terminal and run the following command to remove the quarantine flag:
       ```bash
       xattr -d com.apple.quarantine /Applications/Bettbox.app
       ```

4. **Unable to import subscription links:**
   - **Please make sure to try resetting the link first** to ensure it's active before importing.
   - **Ensure that the imported link is in Clash (Mihomo) format.**
   - If the issue persists, please open an Issue.

5. **To be continued...**

---

## 💻 Development

Example for Windows:

* You need a Windows device (system ≥ Windows 10)
* Other required environment: Git, Visual Studio, Flutter 3.44.x, Golang, Inno Setup, Rust
* `flutter pub get` (get dependencies)
* `dart .\setup.dart windows --arch amd64 --out core` (only build Core)
* `dart .\setup.dart windows --arch amd64 --out app --compatible` (optional compatible version)
* Once built, the final artifacts are located in the `dist/` directory

---

### ☕ Sponsorship

**If you find this project helpful, you can sponsor the development through the following methods:**

* TRON (TRC-20): <code>TCkTtZfF2WrciZLaJj3e1aqrh3zdTnCkDa</code>
* EVM Compatible: <code>0xF8B1B39431013359D83F38a4e403087624618E67</code>
* Solana: <code>C2YQPcKR2YmrPtBvkE13wckjgescUfMA5HzUioR4rQUd</code>
* Bitcoin: <code>bc1qu950cl6035qvllmzk6cfw3l30j2lg3cq9n6g6h</code>

---

## ❤️ Acknowledgements

**[FlClash GUI](https://github.com/chen08209/FlClash)** - **[Mihomo Core](https://github.com/MetaCubeX/mihomo)**

* The Windows digital signature for the Bettbox project is provided by **[SignPath](https://signpath.io)**, and the code has passed security reviews.
* Heartfelt thanks to the **SignPath Foundation** for their generous support of the open-source community.

Other open-source project references (listed in chronological order):

[CMFA](https://github.com/MetaCubeX/ClashMetaForAndroid), [Sparkle](https://github.com/xishang0128/sparkle), [SFA](https://github.com/SagerNet/sing-box-for-android), [HUSI](https://github.com/xchacha20-poly1305/husi), [V2rayN](https://github.com/2dust/v2rayN)

---

## 📄 License

Licensed under the GPL-3.0 License.
