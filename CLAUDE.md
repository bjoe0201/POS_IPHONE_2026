# CLAUDE.md

> **重要提醒：**
> - 使用者操作說明（含畫面截圖）請見 [`README.md`](README.md)。
> - 完整技術開發文件（技術棧、建置、資料庫、發佈 / TestFlight）請見 [`DEVELOPER.md`](DEVELOPER.md)。
> - 每次異動架構或導航流程時，必須同步更新 `README.md`、`DEVELOPER.md` 與本文件。
> - 本專案由 Android 版 [`POS_ANDROID_2026`](https://github.com/bjoe0201/POS_ANDROID_2026) 移植而來；移植計畫見 [`PLANS/PORTING_PLAN.md`](PLANS/PORTING_PLAN.md)。

此檔案提供 Claude Code（claude.ai/code）與其他 AI agent 在此儲存庫中進行程式碼作業時的指引。

## 專案概要

火鍋店 POS 的 **iPhone（SwiftUI）原生版**，由 Android 版移植，功能對齊（6 個分頁）。

- **語言 / UI**：Swift + SwiftUI（單一深色主題）
- **最低系統**：iOS 15（目標機 iPhone 8）。**禁止使用 iOS 16+ API**（如 `TextField(axis:)`、`lineLimit(_: Range)`、`.scrollContentBackground` 等）；需要時用 iOS 15 相容寫法。
- **Bundle ID**：`b2p.idv.tw.pos`
- **資料庫**：GRDB.swift（SQLite）
- **設定儲存**：UserDefaults（封裝為 `SettingsStore`）
- **列印**：藍牙熱感印表機（芯烨 XYSDK / BLE，文字模式）+ AirPrint + PDF
- **壓縮備份**：ZIPFoundation
- **DI**：手動容器 `AppContainer` + SwiftUI 環境注入（取代 Android Hilt）
- **專案產生**：**XcodeGen**（`project.yml` → `.xcodeproj`）

## 建置指令

> 需 **完整 Xcode**（不是只有 Command Line Tools）。若 `xcode-select` 指向 CommandLineTools，可在指令前加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。

```bash
# 0) 安裝工具
brew install xcodegen

# 1) 由 project.yml 產生 Xcode 專案（.xcodeproj 不入版控，每次改 project.yml 都要重跑）
xcodegen generate

# 2) 開啟，Xcode 會自動解析 SPM 套件（GRDB、ZIPFoundation）
open POS_IPHONE_2026.xcodeproj

# 3) CLI 建置（實機架構；模擬器見下方限制）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project POS_IPHONE_2026.xcodeproj -scheme POS \
  -destination 'generic/platform=iOS' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

> ⚠️ **熱感印表機庫只能在實機建置／測試**：`POS/ThirdParty/XYSDK/XYSDK.a` 的 `arm64` 切片是 **iOS 裝置**版，無 `arm64-simulator` 切片。Apple Silicon Mac 的模擬器會 **連結失敗**（`ld: building for 'iOS-simulator', but linking in object file … built for 'iOS'`）。請用 `generic/platform=iOS` 並在實機（iPhone 8）測試。Intel Mac 的模擬器可用 `x86_64` 切片。

## 版本更新方式

於 `project.yml` 的 `targets.POS.settings.base` 維護：

- `MARKETING_VERSION`：對外版本號（`major.minor.patch`）。
- `CURRENT_PROJECT_VERSION`：Build 號，**每次上傳 TestFlight 必遞增**。
- 改完務必 `xcodegen generate` 才會寫入專案。
- 版本顯示於登入頁與設定頁（讀 `AppInfo`，來源為 Info.plist）。

## 發佈 / TestFlight（重點）

完整步驟見 `DEVELOPER.md`。關鍵：

- 需付費 Apple Developer Program；先在 Developer 後台註冊 App ID `b2p.idv.tw.pos`，再於 App Store Connect 建立 App（填 SKU）。
- Xcode：Signing & Capabilities 勾自動簽章、選 Team；裝置選 `Any iOS Device (arm64)` → Archive → Distribute → Upload。
- App 圖示為單一 1024×1024、**無 alpha**（`POS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png`），其餘尺寸由 Xcode 產生。
- 出口合規：本 App 僅用 HTTPS 與系統 SHA-256（豁免），選「否，不使用非豁免加密」。

## 架構

### 分層結構

```
project.yml                       — XcodeGen 設定（iOS15、bundle id、SPM、版號、圖示、XYSDK 連結與藍牙權限）
POS/
  App/
    POSApp.swift                  — @main；scenePhase 進背景自動備份；注入 container/settings/thermalPrinter 環境物件
    AppContainer.swift            — 手動 DI：AppDatabase、SettingsStore、ThermalPrinterManager、5 個 Repository
    AppTab.swift                  — 6 分頁列舉（順序、標籤、emoji、依設定顯示）
    RootView.swift                — Login ↔ Home 切換
    HomeView.swift                — 自繪底部導航列
  Data/
    Models/                       — 6 個 GRDB 記錄（對應 Android Room entity；欄位 / 表名刻意一致）
    Database/AppDatabase.swift    — DatabaseQueue + DatabaseMigrator("v4_schema") + 預設資料 seeding + resetToDefaults()
    Repositories/                 — 對應 Room DAO；ValueObservation → Combine publisher（響應式）
    Settings/SettingsStore.swift  — UserDefaults + CryptoKit SHA-256（PIN）
  Features/
    Login / Order / Reservation / Menu / Table / Report / Settings
  Common/
    Theme/PosTheme.swift          — 顏色 token（對應 Android PosColors；以 Theme.xxx 取用）
    Components/                   — ScreenHeader、RepeatableButton、PlaceholderScreen
    Util/                         — DateBoundary、Formatters、Haptics、SoundEffects、PdfReportBuilder、
                                    BackupManager、FolderBookmark、Exporting、ThermalPrinterManager
  ThirdParty/
    XYSDK/                        — 廠商靜態庫 XYSDK.a + include/XYSDK/*.h（由 sources 排除，靠連結與標頭路徑使用）
    Bridge/                       — XYPrinterBridge.{h,m}（ObjC 薄橋接）+ POS-Bridging-Header.h
  Resources/Assets.xcassets/      — AppIcon（單一 1024，無 alpha）
PLANS/                            — PORTING_PLAN.md、PRINTER_XP-Q90EC_iOS.md
```

### 導航流程

`LoginView`（PIN 驗證通過）→ `HomeView`（6 分頁自繪底部列）

底部分頁（依序）：**記帳**（Order）· **訂位**（Reservation）· **菜單管理**（Menu）· **桌號設定**（Table）· **報表**（Report）· **設定**（Settings）

- **記帳** 與 **設定** 為必要分頁，永遠顯示。
- 其餘分頁可於設定「功能頁面」個別開關（`AppTab.isVisible(in:)`）；停用分頁若正在顯示應自動跳回記帳。

### 資料庫結構（schema version 4，與 Android 對齊）

| Table | 主要欄位 |
|-------|---------|
| `menu_groups` | code(PK), name, sortOrder, isActive |
| `menu_items` | id(PK), name, price, category, isAvailable, sortOrder |
| `orders` | id(PK), tableId, tableName(快照), remark, createdAt, closedAt, status, isDeleted |
| `order_items` | id(PK), orderId(FK→orders, cascade), menuItemId, name/price(快照), menuGroupCode/menuGroupName(快照), quantity |
| `tables` | id(PK), tableName(≤20), seats, remark, isActive, sortOrder |
| `reservations` | id(PK), tableId, tableName, guestName, guestPhone, guestCount, date, startTime, endTime, importance, remark, createdAt |

- 時間欄位（createdAt/closedAt）為 **毫秒 epoch**，與 Android `System.currentTimeMillis()` 一致（`Date.nowMillis`，定義於 `Order.swift`）。
- 表名與欄位刻意與 Android Room 一致，方便日後資料互通。
- `MenuGroup` 是 `PersistableRecord`（String code 主鍵）；其餘為 `MutablePersistableRecord`（`Int64?` id 自增）。

### DI（AppContainer）

`AppContainer` 於 App 啟動時建立 `AppDatabase`、`SettingsStore`、`ThermalPrinterManager` 與 5 個 Repository，並透過 `.environmentObject(...)` 注入。ViewModel 用 `@StateObject`，以 `init(container:)` 取得依賴。啟動時呼叫 `orderRepository.cancelEmptyOpenOrders()` 清理孤兒空訂單。

### 重要常數 / 慣例

- `CATEGORIES` 清單（順序 + 顯示名稱）位於 `POS/Features/Order/OrderViewModel.swift`，供菜單與其他畫面共用。
- 預設 PIN：`1234`（SHA-256）。`SettingsStore.verifyPin` / `setPin`；連續錯誤鎖定邏輯見 Login。
- 預設資料：6 群組、17 範例菜單、1～8 號桌（`AppDatabase` seeding）。
- **日期邊界**：App 內部以本機日界線 millis 表示「某日」，相關轉換集中在 `DateBoundary`。
- 顏色一律走 `Theme.xxx`（`PosTheme.swift`），勿硬寫色碼。

### SettingsStore（UserDefaults keys）

PIN（`pin_hash` / `is_default_pin`）、分頁開關（`tab_*_enabled`）、訂位（`biz_start/end`、`break_start/end`、`default_duration`、`calendar_chips_per_row`）、自動備份（`auto_backup_enabled` / `_idle_minutes` / `_retention_days`）、點餐長按（`qty_repeat_interval_ms` / `qty_repeat_initial_delay_ms`、`haptic_enabled`）、列印（`print_checkout_enabled`）、PDF（`pdf_printer_enabled` / `pdf_printer_tree_uri`）。
熱感印表機所選裝置另存於 `ThermalPrinterManager`（`thermal_printer_id` / `thermal_printer_name`）。

## 備份 / 還原

- **匯出**：`BackupManager.exportZip` 以 GRDB 線上備份產生乾淨 SQLite → 打包 `.zip` → 分享 sheet。
- **匯入**：解出後以 GRDB 線上備份**覆蓋現用資料庫**；`ValueObservation` 自動重新發佈，畫面即時更新，**不需重啟 App**。
- **自動備份**：進背景（`scenePhase == .background`）存到 `Documents/auto_backup/`，保留最新數份。
- **跨平台（與 Android）互通：尚未實作，且目前暫停**。兩邊 zip 皆原生 SQLite，Android Room 會驗證 `room_master_table` 的 identity_hash 而拒絕外來檔。未來互通需走平台中立的 **JSON（逐列）** 格式，屬獨立功能；目前以**各平台各自匯入匯出**為主。

## 列印

### 藍牙熱感印表機（芯烨 XP-Q90EC）

範圍鎖定 **BLE + 文字（ESC/POS）模式**；**不做** WiFi、點陣圖（raster）、標籤（TSPL）。整合規劃與里程碑見 [`PLANS/PRINTER_XP-Q90EC_iOS.md`](PLANS/PRINTER_XP-Q90EC_iOS.md)。

- `POS/ThirdParty/XYSDK/`：廠商靜態庫 `XYSDK.a` + 標頭（class 為 `XYBLEManager`、`XYCommand`〔宣告於 `PosCommand.h`〕等）。
- `POS/ThirdParty/Bridge/XYPrinterBridge.{h,m}`：**ObjC 薄橋接**，把 `XYBLEManager` 收斂成乾淨介面（`startScan/connect/write/...`），並把所有 BLE 回呼 `dispatch` 回**主執行緒**。橋接層存在的理由：Swift 匯入 ObjC 會改名（如 `writeData:`→`write(_:)`、`XYdidFailToConnect…`→`xyBridgeDidFail(toConnect:…)`），全部關在一處控制。
- `POS/Common/Util/ThermalPrinterManager.swift`：`ObservableObject`，`@Published devices/state/connectedId/statusMessage`，掃描→連線→測試列印（目前 ASCII）→記住裝置（UserDefaults）→自動重連 helper。`EscPos` 以 `XYCommand` 組指令。
- `project.yml` 關鍵設定：`framework: POS/ThirdParty/XYSDK/XYSDK.a`（embed:false）、連結 `CoreBluetooth/SystemConfiguration/CFNetwork`、`OTHER_LDFLAGS: -ObjC`、`HEADER_SEARCH_PATHS` 指向 `include/XYSDK`、`SWIFT_OBJC_BRIDGING_HEADER` 指向 `Bridge/POS-Bridging-Header.h`、`INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`、`sources` 排除 `ThirdParty/XYSDK/**`。
- **進度**：P1 已完成（接 SDK + 設定頁偵測/連線/測試列印），待實機驗證。P2＝收款收據文字版 + 收款後自動列印 + **中文驗證**（依印表機字碼表 Big5/GBK；若亂碼再評估點陣）。P3＝列印路由（有熱感機走 BLE，否則 AirPrint）。

### AirPrint / PDF

`Exporting.printPDF`（`UIPrintInteractionController`）為通用後援；`PdfReportBuilder`（`UIGraphicsPDFRenderer`）產生報表 / 收據 PDF，可依設定存到 `FolderBookmark`（security-scoped bookmark）資料夾或分享。

### App Store 審核注意

- 走 **BLE（CoreBluetooth）**：一般 BLE 周邊**不需 MFi 認證**（若改走藍牙 Classic / External Accessory 才需要）。
- 必備 `NSBluetoothAlwaysUsageDescription`；核心 POS 功能**不可依賴印表機**（沒接機也能正常記帳結帳）。
- 上架前建議補一份 app 層級 `PrivacyInfo.xcprivacy`（因用了 UserDefaults 等 required-reason API）。

## 規劃文件

- 移植計畫與里程碑：`PLANS/PORTING_PLAN.md`
- 印表機整合：`PLANS/PRINTER_XP-Q90EC_iOS.md`

---

## ⚠️ 重要事項

**每次異動程式架構或導航流程時，必須同步更新以下三份文件：**

- **`README.md`**：功能總覽、畫面截圖（使用者導向）
- **`DEVELOPER.md`**：技術規格、建置、資料庫、發佈 / TestFlight（開發者導向）
- **`CLAUDE.md`**：分層結構、導航、資料庫、重要常數、備份 / 列印（AI 指引）

需要更新的常見情境：

- 新增或移除底部分頁（`AppTab`）
- 新增或移除 Screen / Feature
- 新增或修改 GRDB 記錄 / migration / Repository
- 新增或修改 UserDefaults 設定鍵（`SettingsStore`）
- 變更備份 / 還原或列印機制
- 版號遞增（`project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`，並 `xcodegen generate`）
- 異動 `project.yml`（依賴、連結、權限）後務必 `xcodegen generate`

### 開發慣例提醒

- 維持 iOS 15 相容，勿引入 iOS 16+ API。
- 顏色走 `Theme.xxx`；時間用毫秒 epoch；欄位 / 表名與 Android 對齊。
- 與 SDK 互動一律經過 `XYPrinterBridge`，勿在 Swift 直接散落呼叫 `XYBLEManager`。
- 跨平台備份目前**暫停**，勿自行重啟該功能；要做請先確認需求。
