# 火鍋店 POS（iPhone / iOS 版）

由 [`POS_ANDROID_2026`](https://github.com/bjoe0201/POS_ANDROID_2026) 移植的 SwiftUI 原生版本。

- **平台**：iOS 15+（iPhone 8 可用）
- **UI**：SwiftUI
- **資料庫**：GRDB.swift（SQLite，schema 與 Android 版一致，`.zip` 備份可跨平台還原）
- **設定**：UserDefaults
- **列印**：PDF + AirPrint（USB / 藍牙 ESC/POS 為 Android 限定，iOS 不支援）

> 完整移植計畫見 [`PLANS/PORTING_PLAN.md`](PLANS/PORTING_PLAN.md)。

---

## 開發環境需求

- macOS + **Xcode 14 以上**（含 iOS SDK；只有 Command Line Tools 無法建置 iOS App）
- [XcodeGen](https://github.com/yonbergman/xcodegen)（`brew install xcodegen`）— 由 `project.yml` 產生 Xcode 專案

## 建置步驟

```bash
# 1) 產生 Xcode 專案（.xcodeproj 不納入版控，需自行產生）
xcodegen generate

# 2) 開啟專案，Xcode 會自動解析 SPM 套件（GRDB、ZIPFoundation）
open POS_IPHONE_2026.xcodeproj

# 3) 選擇模擬器或實機，Cmd+R 建置執行
```

### 安裝到實機 iPhone 8

1. Xcode → Signing & Capabilities，選擇你的 Apple ID（免費帳號即可，簽章效期 7 天）。
2. iPhone 以 USB 連接、信任此電腦。
3. 選擇該裝置為執行目標，Cmd+R。

---

## 專案結構

```
project.yml                 # XcodeGen 設定（iOS 15、bundle id、SPM 依賴）
POS/
  App/                      # 進入點、DI 容器、根視圖
  Data/
    Models/                 # GRDB 記錄（對應 Room entity）
    Database/               # AppDatabase（schema、seeding）
    Repositories/           # 對應 Room DAO + Repository
    Settings/               # SettingsStore（UserDefaults）
  Features/                 # 各功能畫面（Login / Order / ... ）
  Common/                   # 主題、共用元件、工具
PLANS/                      # 移植計畫文件
```

預設 PIN：**`1234`**（首次登入後請至設定頁修改）。
