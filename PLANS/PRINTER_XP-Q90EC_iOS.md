# XP-Q90EC 熱感印表機 — iPhone 連線與操作方案

> 狀態：**規劃草案，待你檢視**（尚未動任何程式）
> 來源：芯烨（Xprinter）官方 iOS Demo / SDK
> `…/POS_ANDROID_2026/XP-Q90EC/IOSdemo--Newest/`（含 `XPrintDemo` 範例專案、`XYSDK.a`、SDK 文件 HTML）

---

## 1. 結論先講

- XP-Q90EC 在 iOS **可以用**，但**不是走 AirPrint**，而是用芯烨官方 **`XYSDK`**（Objective-C 靜態庫 `XYSDK.a`）。
- **連線方式（已定案）：只做藍牙 BLE**（`XYBLEManager`，走 CoreBluetooth）。WiFi 模式**不做**。
- **列印方式（已定案）：文字模式**——用 **`PosCommand`** 組 ESC/POS 文字指令（對齊、字體大小、分隔線、切紙）送出。
  - 不做點陣圖（`ImageTranster`）、不做標籤（`TscCommand`）。
- 這條路與目前 App 已有的 **AirPrint** 並存：AirPrint 當「通用印表機」後援，XYSDK 專門驅動這台熱感機。

> ⚠️ 文字模式的繁體中文取決於 XP-Q90EC 內建字型／字碼表，便宜熱感機可能缺字或亂碼。先以文字模式驗證；若實機中文不正確，再回頭補點陣圖（raster）方案。

> ⚠️ 重要差異：iOS **不支援**像 Android 那樣的藍牙 SPP / 一般 USB 列印。XP-Q90EC 之所以能在 iOS 用，是因為它支援 **BLE**（或 WiFi），且廠商提供了 iOS SDK。

---

## 2. SDK 內容

`XYSDK/`
- `XYSDK.a`：靜態庫（Objective-C）。
- `include/XYSDK/`：
  - `XYBLEManager.h` — 藍牙連線管理（掃描/連線/送資料，含 delegate 回呼）
  - `XYWIFIManager.h` — WiFi 連線管理（IP+Port）
  - `PosCommand.h` — ESC/POS 收據指令（回傳 `NSData`）
  - `TscCommand.h` — TSPL 標籤指令
  - `ImageTranster.h` — 圖片/點陣圖處理
  - `XYSDK.h` — 總說明與匯入

需額外連結的系統框架（SDK 文件指定）：
`CoreBluetooth.framework`、`SystemConfiguration.framework`、`CFNetwork.framework`。

---

## 3. 藍牙（BLE）連線與列印流程

對應 `XYBLEManager`（單例 + delegate）：

```
1. 建立： [XYBLEManager sharedInstance]，設定 delegate（建立當下即自動開始掃描）
2. 掃描： XYstartScan
   → 回呼 XYdidUpdatePeripheralList:RSSIList:  取得周邊清單（CBPeripheral 陣列）
3. 連線： XYconnectDevice:(CBPeripheral*)
   → 成功 XYdidConnectPeripheral:
   → 失敗 XYdidFailToConnectPeripheral:error:
4. 送資料：XYWriteCommandWithData:(NSData*)            （或帶 callback 版本）
   → 回呼 XYdidWriteValueForCharacteristic:error:  判斷是否成功
5. 斷線： XYdisconnectRootPeripheral / 回呼 XYdidDisconnectPeripheral:
```

收據資料（`NSData`）由 `PosCommand` 類方法組出來（對齊、文字、字體大小、切紙、圖片等），再丟給 `XYWriteCommandWithData:` 送出。

### 使用者操作（預期體驗）
1. 印表機開機、開藍牙、在手機附近。
2. App「設定 → 印表機」按**偵測**，列出掃描到的裝置。
3. 選擇 XP-Q90EC → **測試列印**確認。
4. 之後「收款後自動列印收據」「報表列印」就會送到這台。

---

## 4. WiFi / 網路連線 — 不做

本次範圍只做 BLE，`XYWIFIManager` 不納入。（保留紀錄：未來若需固定櫃台網路印表機，可用 `XYConnectWithHost:port:` 連 IP+9100。）

---

## 5. 中文收據（文字模式）

- 用 `PosCommand` 直接送文字指令（對齊、倍寬倍高、分隔線、切紙）。
- 繁體中文是否正確，取決於 XP-Q90EC 內建字型與**字碼表設定**（常見需設 Big5 / GBK 相關 code page）；實作時會嘗試設定對應字碼表。
- **驗收重點**：實機印一張含中文品項名（如「鴛鴦鍋」「梅花豬肉片」）的收據，確認不缺字、不亂碼。若不行 → 再升級為點陣圖（raster）方案。

---

## 6. 整合到本 SwiftUI App 需要做的事

| 步驟 | 內容 |
|------|------|
| a. 納入 SDK | 把 `XYSDK.a` + `include/` 放進專案，於 `project.yml` 設定 library search path、`-ObjC` linker flag、連結 3 個系統框架 |
| b. Bridging header | 新增 Objective-C bridging header，`#import "XYSDK.h"`，讓 Swift 呼叫 |
| c. 權限 | Info.plist 加 `NSBluetoothAlwaysUsageDescription`（BLE） |
| d. 封裝 Manager | 寫一個 `ThermalPrinterManager`（Swift）包住 `XYBLEManager`：掃描→連線→送 `PosCommand` 文字指令 |
| e. 收據內容 | 用 `PosCommand` 文字版組收據（桌號、品項、金額、合計、切紙） |
| f. 設定頁 UI | 「印表機」區塊：偵測、裝置清單、選擇、測試列印、記住所選裝置（存 UserDefaults） |
| g. 列印路由 | 收款 / 報表列印時，若已選熱感機 → 走 XYSDK；否則 → 維持 AirPrint |

> SDK 是 Objective-C 靜態庫，能與 SwiftUI/SPM 並存，但需用 bridging header；且 XcodeGen 要加對應的連結設定。

---

## 7. 我實作前必須先驗證的事項（目前未確認）

1. **`XYSDK.a` 支援的架構**：是否含 `arm64`（實機）與模擬器切片（arm64-sim）。若只有實機切片，模擬器無法連結，需用實機測。（用 `lipo -info` 查）
2. **XP-Q90EC 的紙張型態**：收據機（58/80mm）還是標籤機？Demo 同時有收據(`BillPrintingVC`)與標籤(`TagPrintingVC`)；本 POS 只需收據。
3. **`PosCommand` 確切 API**：對齊、字體倍寬倍高、切紙、光柵圖的方法簽名（讀 `PosCommand.h`）。
4. **BLE 服務/特徵**：SDK 已封裝，但要確認 XP-Q90EC 韌體與此 SDK 相容（用 Demo 實連一次最快）。
5. **Bluetooth 權限字串**與背景模式需求。

---

## 8. 建議里程碑（待你同意後再動工）

- **P1**：把 SDK 與 bridging 接起來，能編譯；設定頁「印表機」能 **掃描 + 連線 + 測試列印**（先印英數/金額一行）。
- **P2**：以 `PosCommand` 文字版組**收款收據**（桌號、品項、金額、合計、切紙），接上「收款後自動列印」；實機驗證中文。
- **P3**：選定裝置記憶（UserDefaults）、斷線重連、列印路由（有熱感機走 BLE，否則 AirPrint）。

> 點陣圖中文、WiFi、標籤均**不在本次範圍**；若文字模式中文驗收失敗，再另開點陣方案。

---

## 9. 與現況的關係

- 目前 App 列印走 **AirPrint + PDF**（M6/M7 已完成）。本方案是**新增**對 XP-Q90EC 熱感機的原生支援，不影響既有 AirPrint。
- 跨平台備份（JSON）一樣仍是另一個獨立待辦，與本印表機方案無關。

> 請檢視本文件。確認方向（BLE 優先？是否要點陣中文？里程碑範圍）後，我再開始接 SDK。
