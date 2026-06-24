//
//  XYPrinterBridge.h
//  薄橋接：把芯烨 XYSDK 的藍牙（XYBLEManager）介面包成乾淨、Swift 友善的 API。
//  目的：(1) 固定方法名稱，避免 Swift 匯入時大小寫改名造成呼叫困擾；
//       (2) 把 BLE 回呼統一切回主執行緒，讓 Swift 端 @Published 更新安全。
//  範圍：僅 BLE + 文字模式；不含 WiFi 與標籤。
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@protocol XYPrinterBridgeDelegate <NSObject>
/// 掃描到的周邊清單更新（peripherals 與 rssi 索引對應）
- (void)xyBridgeDidUpdateDevices:(NSArray<CBPeripheral *> *)peripherals
                            rssi:(NSArray<NSNumber *> *)rssi;
/// 連線成功
- (void)xyBridgeDidConnect:(CBPeripheral *)peripheral;
/// 連線失敗
- (void)xyBridgeDidFailToConnect:(CBPeripheral *)peripheral error:(nullable NSError *)error;
/// 斷線
- (void)xyBridgeDidDisconnect:(CBPeripheral *)peripheral;
/// 寫入資料完成（error 為 nil 表示成功）
- (void)xyBridgeDidWriteWithError:(nullable NSError *)error;
@end

@interface XYPrinterBridge : NSObject

@property (nonatomic, weak, nullable) id<XYPrinterBridgeDelegate> delegate;

+ (instancetype)shared;

- (void)startScan;
- (void)stopScan;
- (void)connect:(CBPeripheral *)peripheral;
- (void)disconnect;
/// 送出已組好的 ESC/POS 指令資料
- (void)writeData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
