# DEVELOPER.md — 技術文件

火鍋店 POS iPhone 版的開發者文件：技術棧、建置、架構、資料庫、發佈與 TestFlight。
使用者操作說明請見 [`README.md`](README.md)。

---

## 技術棧

| 項目 | 採用 |
|------|------|
| UI | SwiftUI（單一深色主題） |
| 最低系統 | iOS 15（iPhone 8 可用） |
| 資料庫 | [GRDB.swift](https://github.com/groue/GRDB.swift)（SQLite） |
| 設定儲存 | UserDefaults（封裝為 `SettingsStore`） |
| 列印 | AirPrint（`UIPrintInteractionController`）+ PDF（`UIGraphicsPDFRenderer`）+ 藍牙熱感機（芯烨 XYSDK / BLE，僅文字模式） |
| 壓縮備份 | [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) |
| DI | 輕量手動容器 `AppContainer` + SwiftUI 環境注入 |
| 專案產生 | [XcodeGen](https://github.com/yonbergman/xcodegen)（`project.yml`） |

> 套件透過 Swift Package Manager 引入，開啟專案後 Xcode 會自動解析。

---

## 開發環境需求

- macOS + **Xcode 14 以上**（含 iOS SDK；只有 Command Line Tools 無法建置 iOS App）。
- **XcodeGen**：`brew install xcodegen`。

## 建置步驟

```bash
# 1) 由 project.yml 產生 Xcode 專案（.xcodeproj 不入版控）
xcodegen generate

# 2) 開啟，Xcode 自動解析 SPM 套件（GRDB、ZIPFoundation）
open POS_IPHONE_2026.xcodeproj

# 3) 選模擬器或實機，Cmd+R 建置執行
```

> 修改 `project.yml`（bundle id、版號、設定、加入檔案等）後，必須重新 `xcodegen generate`。

---

## 版本與識別碼

於 `project.yml` 的 target `settings.base` 維護：

| 設定 | 值 | 說明 |
|------|----|------|
| `PRODUCT_BUNDLE_IDENTIFIER` | `b2p.idv.tw.pos` | App 唯一識別碼（需在 Apple Developer 後台註冊） |
| `MARKETING_VERSION` | `1.0.0` | 對外版本號 |
| `CURRENT_PROJECT_VERSION` | `3` | Build 號，**每次上傳 TestFlight 需遞增** |
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon` | App 圖示資產名稱 |

---

## 專案結構

```
project.yml                       # XcodeGen 設定（iOS15、bundle id、SPM 依賴、版號、圖示）
POS/
  App/
    POSApp.swift                  # @main 進入點；進背景自動備份（scenePhase）
    AppContainer.swift            # 手動 DI：DB、各 repository、SettingsStore
    AppTab.swift                  # 六分頁定義與依設定動態顯示
    RootView.swift                # Login ↔ Home 切換
    HomeView.swift                # 自繪底部導航列
  Data/
    Models/                       # GRDB 記錄（對應 Android Room entity）
    Database/AppDatabase.swift    # 建表 migration + 預設資料 seeding + 初始化
    Repositories/                 # 對應 Room DAO + Repository（ValueObservation 響應式）
    Settings/SettingsStore.swift  # UserDefaults + CryptoKit SHA-256
  Features/
    Login / Order / Reservation / Menu / Table / Report / Settings
  Common/
    Theme/PosTheme.swift          # 顏色（對應 Android PosColors）
    Components/                   # ScreenHeader、RepeatableButton、PlaceholderScreen
    Util/                         # DateBoundary、Formatters、Haptics、SoundEffects、
                                  #   PdfReportBuilder、BackupManager、FolderBookmark、Exporting
  Resources/Assets.xcassets/      # AppIcon（1024 單尺寸，無 alpha）
PLANS/PORTING_PLAN.md             # 移植計畫與里程碑
```

### 導航流程
`LoginView`（PIN 驗證）→ `HomeView`（六分頁：記帳 · 訂位 · 菜單管理 · 桌號設定 · 報表 · 設定）。
記帳與設定永遠顯示，其餘可於設定頁開關；停用中分頁若正在顯示會自動跳回記帳。

---

## 資料庫結構（schema version 4，與 Android 對齊）

| Table | 主要欄位 |
|-------|---------|
| `menu_groups` | code(PK), name, sortOrder, isActive |
| `menu_items` | id(PK), name, price, category, isAvailable, sortOrder |
| `orders` | id(PK), tableId, tableName(快照), remark, createdAt, closedAt, status, isDeleted |
| `order_items` | id(PK), orderId(FK→orders, cascade), menuItemId, name/price(快照), menuGroupCode/menuGroupName(快照), quantity |
| `tables` | id(PK), tableName(≤20), seats, remark, isActive, sortOrder |
| `reservations` | id(PK), tableId, tableName, guestName, guestPhone, guestCount, date, startTime, endTime, importance, remark, createdAt |

- 時間欄位（createdAt/closedAt）為**毫秒 epoch**，與 Android `System.currentTimeMillis()` 一致。
- 表名與欄位刻意與 Android Room 一致，方便日後資料互通。
- 預設資料、PIN（`1234`，SHA-256）、錯誤鎖定（3 次 / 30 秒）等常數見 `AppDatabase` 與 `SettingsStore`。

---

## 備份 / 還原機制

- **匯出**：`BackupManager.exportZip` 以 GRDB 線上備份產生乾淨的單一 SQLite → 打包為 `.zip`（內含 `pos_database`）→ 透過分享 sheet 存檔。
- **匯入**：解出 `pos_database` → 以 GRDB 線上備份**覆蓋現用資料庫**；`ValueObservation` 自動重新發佈，畫面即時更新，**不需重啟 App**。
- **自動備份**：進入背景時（`scenePhase == .background`）存到 App `Documents/auto_backup/`，保留最新數份。
- **PDF/收據**：`PdfReportBuilder`（`UIGraphicsPDFRenderer`）；收款後依設定存到 `FolderBookmark`（security-scoped bookmark）指定的資料夾，或 AirPrint 列印。

> 跨平台（與 Android）備份互通**尚未實作**：兩邊的 zip 是原生 SQLite，Android 的 Room 會驗證 `room_master_table` 的 identity_hash 而拒絕外來檔。未來若要互通，需走平台中立的 JSON（逐列）格式，屬獨立功能。

---

## 藍牙熱感印表機（芯烨 XP-Q90EC）

僅支援 **BLE + 文字（ESC/POS）模式**；不含 WiFi、點陣圖、標籤。整合規劃見 [`PLANS/PRINTER_XP-Q90EC_iOS.md`](PLANS/PRINTER_XP-Q90EC_iOS.md)。

```
POS/ThirdParty/
  XYSDK/                       # 廠商 SDK（不入版控 sources，靠連結與標頭搜尋路徑使用）
    XYSDK.a                    # Objective-C 靜態庫（i386/armv7/x86_64/arm64）
    include/XYSDK/*.h          # SDK 標頭
  Bridge/
    XYPrinterBridge.{h,m}      # 薄橋接：固定方法名、回呼統一切回主執行緒
    POS-Bridging-Header.h      # Swift 橋接標頭（只 import 橋接層 + PosCommand）
POS/Common/Util/ThermalPrinterManager.swift   # @Published 狀態、掃描/連線/測試列印、記住裝置
```

`project.yml` 對應設定：`framework: XYSDK.a`（embed:false）、連結 `CoreBluetooth/SystemConfiguration/CFNetwork`、`OTHER_LDFLAGS: -ObjC`、`HEADER_SEARCH_PATHS` 指向 `include/XYSDK`、`SWIFT_OBJC_BRIDGING_HEADER` 指向橋接標頭、藍牙權限字串 `NSBluetoothAlwaysUsageDescription`。

> Swift 匯入 Objective-C 時會改名（如 `writeData:`→`write(_:)`、`XYdidFailToConnect…`→`xyBridgeDidFail(toConnect:…)`），橋接層即是為了把這些介面收斂在可控的一處。

## App 圖示

`POS/Resources/Assets.xcassets/AppIcon.appiconset/`，採單一 1024×1024（無 alpha 透明，符合 App Store 規定），Xcode 建置時自動產生其餘尺寸。更換圖示只需替換 `AppIcon1024.png`。

---

## 發佈到 TestFlight

需要**付費的 Apple Developer Program** 會員。

1. **註冊識別碼**：[Developer 後台](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → ＋ → App IDs → App → Explicit `b2p.idv.tw.pos` → Register。
2. **App Store Connect** → 我的 App → ＋ 新的 App：平台 iOS、選套件識別碼 `b2p.idv.tw.pos`、填 SKU（如 `POS-IPHONE-2026`）。
3. **Xcode 簽章**：target POS → Signing & Capabilities → 勾 Automatically manage signing、選 Team。
4. **打包**：裝置選 `Any iOS Device (arm64)` → Product → Archive。
5. **上傳**：Organizer → Distribute App → App Store Connect → Upload。
6. 每次上傳前把 `CURRENT_PROJECT_VERSION` 遞增並 `xcodegen generate`。
7. **TestFlight**：內部測試者用同一 Apple ID 在 TestFlight App 直接看到 build（不必等邀請信）；若出現「缺少出口合規資訊」，本 App 僅用 HTTPS 與系統 SHA-256（豁免），選「否，不使用非豁免加密」。

---

## 已知 / 待驗證事項

- **長按手勢與捲動**：記帳頁菜單卡的 0 距離長按連續加減，與菜單格捲動可能互搶，需實機微調（必要時改 `.onLongPressGesture` 或 simultaneous gesture）。
- **ZIPFoundation API 版本**：`Archive` 採 throwing 初始化；若日後鎖定不同版本需留意 API 差異。
- 跨平台備份互通（見上）為未來功能。
- **熱感印表機只能在實機測試**：`XYSDK.a` 的 `arm64` 切片是 iOS 裝置版，無 `arm64-simulator` 切片，故 Apple Silicon Mac 的模擬器**無法連結**（`ld: building for 'iOS-simulator', but linking in object file … built for 'iOS'`）。請以 `generic/platform=iOS` 建置並在實機（如 iPhone 8）測試。Intel Mac 的模擬器可用 `x86_64` 切片。
- **熱感印表機繁體中文**：目前送 ASCII 測試頁；中文需依印表機字碼表（Big5/GBK）處理，屬 P2，若亂碼再評估點陣方案。
