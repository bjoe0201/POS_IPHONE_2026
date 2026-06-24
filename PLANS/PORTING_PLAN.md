# POS Android → iPhone 移植計畫

> 來源專案：`POS_ANDROID_2026`（Jetpack Compose，~11,500 行 Kotlin / 56 檔）
> 目標專案：`POS_IPHONE_2026`（SwiftUI 原生）
> 文件版本：草案 v1　｜　日期：2026-06-24

---

## 1. 目標與決策（已與你確認）

| 項目 | 決策 |
|------|------|
| 技術路線 | **SwiftUI 原生重寫** |
| 最低系統 | **iOS 15**（iPhone 8 可用） |
| 資料庫 | **GRDB.swift**（SQLite，對應 Room） |
| 設定儲存 | **UserDefaults**（對應 DataStore） |
| 列印 | **第一版 PDF + AirPrint**（USB/藍牙 ESC/POS 不搬） |
| 範圍 | **全功能對等**（六大分頁全做） |
| DI | 輕量手動容器 / `@EnvironmentObject` |
| 專案產生 | **XcodeGen**（`project.yml`，免 GUI 建專案） |

---

## 2. 必要前置作業（需要你做）

1. **安裝 Xcode**（App Store，約 7–12GB）。目前這台 Mac 只有 Command Line Tools，**無法編譯/模擬/部署 iOS**。
   - 裝完執行一次：`sudo xcodebuild -license accept` 與 `xcode-select` 指向 Xcode。
2. **Apple ID**（免費即可）用於實機簽章；免費帳號的 App 簽章有效期 7 天，到期需重簽（重新 build 安裝）。
3. iPhone 8 以 USB 連線、開啟「開發者模式 / 信任此電腦」。

> 在 Xcode 就緒前，我會把**所有原始碼與專案設定寫好**；你只需 `xcodegen generate && open POS_IPHONE_2026.xcodeproj` 即可建置。

---

## 3. iOS 平台限制與對應策略

| Android 功能 | iOS 限制 | 本專案對應 |
|--------------|----------|------------|
| USB ESC/POS 列印 | iOS 不開放 USB host | **改 PDF + AirPrint**（第一版）；熱感機列入後續里程碑 |
| 藍牙 SPP 列印 | iOS 僅 BLE / MFi | 同上，第一版不做 |
| Room | — | **GRDB**（相同 SQLite schema，可沿用既有 .db 檔結構） |
| DataStore | — | **UserDefaults**（封裝成 `SettingsStore`） |
| Hilt DI | — | 手動 `AppContainer` + SwiftUI 環境注入 |
| SAF（ZIP 備份） | iOS 沙盒 | **UIDocumentPicker / Files App**；ZIP 用 `Compression` / `ZIPFoundation` |
| 觸覺回饋 | — | `UIImpactFeedbackGenerator` |
| 音效（收款） | — | `AVAudioPlayer` |
| Material3 DatePicker UTC 時區坑 | — | Swift 用本機 `Calendar`，需同樣注意日界線 |
| `PdfDocument` | — | `UIGraphicsPDFRenderer` |

---

## 4. 目標專案結構

```
POS_IPHONE_2026/
  project.yml                      # XcodeGen 設定（iOS 15, bundle id, GRDB SPM）
  POS/
    App/
      POSApp.swift                 # @main App 進入點
      AppContainer.swift           # 手動 DI 容器（DB、repositories、settings）
      RootView.swift               # Login ↔ Home 切換
    Data/
      Database/
        AppDatabase.swift          # GRDB DatabaseQueue、migration、預設資料 seeding
      Models/                      # 6 個 GRDB 記錄（對應 Room entity）
        MenuGroup.swift
        MenuItem.swift
        Order.swift
        OrderItem.swift
        Table.swift
        Reservation.swift
      Repositories/                # 對應 Room DAO + Repository
        MenuGroupRepository.swift
        MenuRepository.swift
        OrderRepository.swift
        ReservationRepository.swift
        TableRepository.swift
      Settings/
        SettingsStore.swift        # UserDefaults，含 PIN SHA-256、各開關鍵
    Features/
      Login/                       # PIN 登入（鎖定 30 秒）
      Order/                       # 記帳點餐（核心）
      Reservation/                 # 訂位月曆 + 時段格線 + 對話框
      Menu/                        # 菜單 / 群組管理
      Table/                       # 桌號設定
      Report/                      # 報表 + 圓餅圖 + CSV/PDF/AirPrint
      Settings/                    # 設定頁
    Common/
      Theme/                       # 顏色、字型（對應 PosColors）
      Components/                  # 共用 UI 元件
      Util/
        DateBoundary.swift         # 本機日界線換算（對應 DatePickerDateUtils）
        Haptics.swift
        SoundEffects.swift
        PdfBuilder.swift           # 報表 / 收據 PDF（對應 ReportPdfBuilder）
        AirPrint.swift             # UIPrintInteractionController 封裝
        BackupManager.swift        # ZIP 匯出 / 匯入（對應 BackupManager）
        Csv.swift                  # 報表 CSV（UTF-8 BOM）
  PLANS/
    PORTING_PLAN.md
```

---

## 5. 資料模型（沿用 Android schema，version 4）

| Table | 主要欄位 |
|-------|---------|
| `menu_groups` | code(PK), name, sortOrder, isActive |
| `menu_items` | id(PK), name, price, category, isAvailable, sortOrder |
| `orders` | id(PK), tableId(FK), tableName(快照), remark, createdAt, closedAt, status, isDeleted |
| `order_items` | id(PK), orderId, menuItemId, name/price(快照), menuGroupCode/menuGroupName(快照), quantity |
| `tables` | id(PK), tableName(≤20), seats, remark, isActive, sortOrder |
| `reservations` | id(PK), tableId, tableName, guestName, guestPhone, guestCount, date, startTime, endTime, importance, remark, createdAt |

**預設資料 seeding**（首次建立）：6 個菜單群組、17 個菜單品項、8 張桌號 —— 與 Android 完全相同。

**常數**：分類順序 `CATEGORIES`、預設 PIN `1234`（SHA-256）、錯誤 3 次鎖定 30 秒。

---

## 6. 設定鍵（DataStore → UserDefaults）

PIN 雜湊、各 Tab 開關、營業時間、訂位設定、自動備份、`QTY_REPEAT_INTERVAL_MS` / `QTY_REPEAT_INITIAL_DELAY_MS`、`HAPTIC_ENABLED`、`PRINT_CHECKOUT_ENABLED`、`PDF_PRINTER_ENABLED` / `PDF_PRINTER_TREE_URI`、`CLOUD_BACKUP_ENABLED`（雲端備份在 iOS 改用 iCloud Drive 資料夾，列後續）。
> 印表機相關鍵（`SELECTED_PRINTER_TYPE/ID`、`PRINTER_TEST_PASSED`）第一版以 AirPrint 取代，暫不沿用。

---

## 7. 分階段里程碑

| 階段 | 內容 | 狀態 |
|------|------|------|
| **M0** | 專案骨架：`project.yml`、App 進入點、GRDB、iOS15 target | ✅ 完成 |
| **M1** | 資料層：6 模型 + DB seeding/migration + repositories + SettingsStore | ✅ 完成 |
| **M2** | 登入 + 六分頁導航殼 + 分頁開關 | ✅ 完成 |
| **M3** | 記帳點餐（核心）：選桌、分類、菜單卡、長按連加減、結帳、補登模式 | ✅ 完成 |
| **M4** | 菜單管理 + 桌號設定 | ✅ 完成 |
| **M5** | 訂位：月曆、時段格線、訂位 CRUD | ✅ 完成 |
| **M6** | 報表 + 圓餅圖 + CSV + PDF + AirPrint | ✅ 完成 |
| **M7** | 設定頁 + ZIP 備份匯出/匯入 + 資料庫初始化 + 收據存檔/列印 | ✅ 完成 |

> 全部里程碑程式碼完成。**待安裝 Xcode 後做首次建置與實機驗證**（目前只能做 `swiftc -parse` 語法層檢查）。

> 每個里程碑完成後 commit 到 `POS_IPHONE_2026`，方便你逐步檢視。

---

## 8. UI 從「平板」改「手機(4.7")」的調整原則

- 記帳頁：Android 左菜單右清單的並排，iPhone 8 直式改為**上方桌號列 + 分類 Tab + 菜單格 + 下方可展開的訂單明細 / 結帳列**。
- 報表排行：Android 橫式左清單右圓餅；iPhone 直式改為**圓餅在上、清單在下**，橫式（旋轉）才並排。
- 訂位時段格線：每行時段數依螢幕寬度自適應（手機預設較少）。
- 全程支援直式為主，橫式為輔。

---

## 9. 已知風險 / 待你決定項

1. **iPhone 8 效能**（A11 / 2GB）：報表大量資料、圓餅圖以原生 `Canvas`/`Path` 繪製，注意分段渲染。
2. **熱感印表機**：若日後一定要用熱感機，需提供**型號**，評估其 BLE/MFi 支援，再做 ESC/POS over BLE（獨立里程碑，不在本計畫範圍）。
3. **雲端備份**：Android 用 SAF 任意資料夾；iOS 建議改 **iCloud Drive**，列為後續。
4. **Android 與 iOS 並行維護**：兩套各自獨立，schema 保持一致以利資料互通（ZIP 備份檔可跨平台還原）。

---

## 10. 你檢視後我會開始的第一步

確認本計畫後，我從 **M0 + M1**（專案骨架 + 資料層）動工，完成後 commit 讓你檢視，再往 M2 推進。
