//
//  XYPrinterBridge.m
//

#import "XYPrinterBridge.h"
#import "XYBLEManager.h"   // 由 HEADER_SEARCH_PATHS 指向 ThirdParty/XYSDK/include/XYSDK

@interface XYPrinterBridge () <XYBLEManagerDelegate>
@end

@implementation XYPrinterBridge

+ (instancetype)shared {
    static XYPrinterBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XYPrinterBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 建立 XYBLEManager 單例的當下即會自動開始掃描；設定 delegate 接收回呼。
        [XYBLEManager sharedInstance].delegate = self;
    }
    return self;
}

#pragma mark - 控制

- (void)startScan {
    [[XYBLEManager sharedInstance] XYstartScan];
}

- (void)stopScan {
    [[XYBLEManager sharedInstance] XYstopScan];
}

- (void)connect:(CBPeripheral *)peripheral {
    [[XYBLEManager sharedInstance] XYconnectDevice:peripheral];
}

- (void)disconnect {
    [[XYBLEManager sharedInstance] XYdisconnectRootPeripheral];
}

- (void)writeData:(NSData *)data {
    [[XYBLEManager sharedInstance] XYWriteCommandWithData:data];
}

#pragma mark - XYBLEManagerDelegate（一律切回主執行緒再轉發）

- (void)XYdidUpdatePeripheralList:(NSArray *)peripherals RSSIList:(NSArray *)rssiList {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate xyBridgeDidUpdateDevices:(peripherals ?: @[]) rssi:(rssiList ?: @[])];
    });
}

- (void)XYdidConnectPeripheral:(CBPeripheral *)peripheral {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate xyBridgeDidConnect:peripheral];
    });
}

- (void)XYdidFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate xyBridgeDidFailToConnect:peripheral error:error];
    });
}

- (void)XYdidDisconnectPeripheral:(CBPeripheral *)peripheral isAutoDisconnect:(BOOL)isAutoDisconnect {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate xyBridgeDidDisconnect:peripheral];
    });
}

- (void)XYdidWriteValueForCharacteristic:(CBCharacteristic *)character error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate xyBridgeDidWriteWithError:error];
    });
}

@end
