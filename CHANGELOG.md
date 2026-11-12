# 變更紀錄（Changelog）

本檔記錄 iPhone 版 POS 的對外版本變更。版號格式為 `MARKETING_VERSION (build CURRENT_PROJECT_VERSION)`，於 `project.yml` 維護。

## Unreleased

目前無未發佈變更。

## v1.0.1（TestFlight build 8／專案 build 5）— 2026-11-12

- TestFlight 到期重建：保留 v1.0.1 功能，將專案 build 由 4 遞增為 5；已透過既有 Xcode Cloud 流程成功建置及上傳雲端 build 8。
- 出口合規資訊與 ADM_POS／TESTER_POS 兩個內部群組指派均依使用者確認完成；App Store Connect 顯示「正在測試」、90 天後到期，共 3 位測試者。
- 本機 iOS Release 與雲端 Archive 通過；未執行實機功能測試。
- 同步 README 與技術文件的版本及交接資訊；未變更功能、資料庫與套件版本。

## v1.0.1 (build 4)

### 修正
- 記帳點餐：長按品項的「−」把數量減到 0 後，因按鈕隨即消失導致長按任務未被取消，造成**手機持續振動**且**無法再新增該品項**。改為按鈕離開畫面（`onDisappear`）時強制結束按壓並取消任務。

### 介面調整
- 記帳點餐底部結帳列：「明細」由灰色小字改為**明顯的按鍵樣式**（圖示 + 加大粗體字 + 外框底色）。
- 訂單明細頁：「取消訂單」由灰色小字改為**紅色警示按鍵**（🗑 圖示 + 加大粗體字 + 外框底色）。

## v1.0.0 (build 3)

- 由 Android 版移植的首個 iPhone（SwiftUI）版本，功能對齊 6 個分頁：記帳點餐、訂位、菜單管理、桌號設定、報表、設定。
- 整合藍牙熱感印表機（XP-Q90EC，BLE + 文字模式）P1：偵測、連線、測試列印。
- 資料備份（手動匯出/匯入、進背景自動備份）、報表匯出（CSV / PDF / AirPrint）、PIN 登入。
