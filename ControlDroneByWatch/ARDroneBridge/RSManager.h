//
//  RSManager.h
//  ControlDroneByWatch
//
//  Created by Syugo Saito on 2015/12/10.
//  Copyright © 2015年 Syugo Saito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class RSManager;
@protocol RSManagerDelegate <NSObject>
@optional

- (void)rsManagerDidStartDiscovery:(RSManager *)manager;
- (void)rsManagerDidStopDiscovery:(RSManager *)manager;
- (void)rsManagerDidStartConnecting:(RSManager *)manager;
- (void)rsManagerDidStopConnecting:(RSManager *)manager;
- (void)rsManagerDidDisconnected:(RSManager *)manager;
- (void)rsManagerIsReady:(RSManager *)manager;
- (void)rsManagerDeviceStateRunning:(RSManager *)manager;

- (void)rsManagerOnUpdateBatteryLevel:(RSManager *)manager percentage:(uint8_t)percentage;

@end

@interface RSManager : NSObject

@property (nonatomic, strong) id<RSManagerDelegate>delegate;
@property (nonatomic) BOOL isReady;

- (void)initialize;
- (void)startDiscovery;
- (void)stopDiscovery;
- (void)startConnecting;
- (void)stopConnecting;

// Control
- (void)emergency;
- (void)takeoff;
- (void)landing;

- (void)gazUpStart;
- (void)gazDownStart;
- (void)gazEnd;

- (void)yawLeftStart;
- (void)yawRightStart;
- (void)setYawSpeedPercentage:(int8_t)percentage;
- (void)yawEnd;

- (void)rollLeftStart;
- (void)rollRightStart;
- (void)setRollAnglePercentage:(int8_t)percentage;
- (void)rollEnd;

- (void)pitchForwardStart;
- (void)pitchBackStart;
- (void)setPitchAnglePercentage:(int8_t)percentage;
- (void)pitchEnd;

- (void)steeringStart;
- (void)steeringEnd;

- (void)flipFront;
- (void)flipBack;
- (void)flipRight;
- (void)flipLeft;

- (void)takepicture;

@end
