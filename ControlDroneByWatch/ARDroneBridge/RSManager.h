//
//  RSManager.h
//  ControlDroneByWatch
//
//  Created by Syugo Saito on 2015/12/10.
//  Copyright © 2015年 Syugo Saito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RSManager : NSObject

@property (nonatomic) BOOL isReady;

- (void) startDiscovery;
- (void) stopDiscovery;
- (void) connect;
- (void) disconnect;

// Control
- (void) emergency;
- (void) takeoff;
- (void) landing;

- (void) gazUpStart;
- (void) gazDownStart;
- (void) gazEnd;

- (void) yawLeftStart;
- (void) yawRightStart;
- (void) setYawSpeedPercentage:(int8_t)percentage;
- (void) yawEnd;

- (void) rollLeftStart;
- (void) rollRightStart;
- (void) setRollAnglePercentage:(int8_t)percentage;
- (void) rollEnd;

- (void) pitchForwardStart;
- (void) pitchBackStart;
- (void) setPitchAnglePercentage:(int8_t)percentage;
- (void) pitchEnd;

- (void) steeringStart;
- (void) steeringEnd;

- (void) flipFront;
- (void) flipBack;
- (void) flipRight;
- (void) flipLeft;

- (void) takepicture;

@end
