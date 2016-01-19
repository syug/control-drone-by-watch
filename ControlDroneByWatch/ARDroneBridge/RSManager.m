//
//  RSManager.m
//  ControlDroneByWatch
//
//  Created by Syugo Saito on 2015/12/10.
//  Copyright © 2015年 Syugo Saito. All rights reserved.
//

#import "RSManager.h"
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARDiscovery/ARDiscovery.h>
#import <libARController/ARController.h>

@interface RSManager()

@property (nonatomic, strong) NSArray * services;
@property (nonatomic) ARCONTROLLER_Device_t * deviceController;
@property (nonatomic) dispatch_semaphore_t stateSem;
@property (nonatomic, strong) ARService * service;

@end


@implementation RSManager

- (void)initialize
{
	printlog(@"initialize");
	_services = [NSArray array];
	_deviceController = NULL;
	_stateSem = dispatch_semaphore_create(0);
	_isReady = NO;
}


//////////////////////////////////////////////////
#pragma mark - Discover ARDrone Device
//////////////////////////////////////////////////

/**
 * Start Discovery
 */
- (void)startDiscovery
{
	printlog(@"startDiscovery");
	
	// Add Notification
	[self registerAppNotifications];
	
	// start the discovery
	[[ARDiscovery sharedInstance] start];
	
	if( [self.delegate respondsToSelector:@selector(rsManagerDidStartDiscovery:)] ) {
		[self.delegate rsManagerDidStartDiscovery:self];
	}
}
/**
 * Stop Discovery
 */
-(void) stopDiscovery
{
	printlog(@"stopDiscovery");
	
	// Remove Notification
	[self unregisterAppNotifications];
	
	// stop discovery
	[[ARDiscovery sharedInstance] stop];
	
	if( [self.delegate respondsToSelector:@selector(rsManagerDidStopDiscovery:)] ) {
		[self.delegate rsManagerDidStopDiscovery:self];
	}
}

/**
 * Register app notifications
 */
- (void)registerAppNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidUpdateServices:) name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
}
/**
 * Unregister app notifications
 */
- (void)unregisterAppNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
}

#pragma mark ARDiscovery notification

/**
 * Serviceがdiscoverされた
 */
- (void)discoveryDidUpdateServices:(NSNotification *)notification
{
	// Called when the list of discovered services has changed
	dispatch_async(dispatch_get_main_queue(), ^{
		// リストをアップデートする
		[self updateServicesList:[[notification userInfo] objectForKey:kARDiscoveryServicesList]];
	});
}
/**
 * サービスリストを更新する
 */
- (void)updateServicesList:(NSArray *)services
{
	NSMutableArray * serviceArray = [NSMutableArray array];
	
	for (ARService * service in services)
	{
		// only the ble services
		if ([service.service isKindOfClass:[ARBLEService class]])
		{
			[serviceArray addObject:service];
		}
	}
	
	_services = serviceArray;
	
	if (_services.count>0) {
		// 接続を開始する
		[self startConnecting];
	}
}

//////////////////////////////////////////////////
#pragma mark - Connect ARDrone Device
//////////////////////////////////////////////////

/**
 * Start Connecting
 */
- (void)startConnecting
{
	// Discoveryを停止
	[self stopDiscovery];
	// Controllerを設定
	[self setupController];
	
	if( [self.delegate respondsToSelector:@selector(rsManagerDidStartConnecting:)] ) {
		[self.delegate rsManagerDidStartConnecting:self];
	}
}
/**
 * Stop Connecting
 */
- (void)stopConnecting
{
	[self stopDiscovery];
	[self resetController];
	
	if( [self.delegate respondsToSelector:@selector(rsManagerDidStopConnecting:)] ) {
		[self.delegate rsManagerDidStopConnecting:self];
	}
}


#pragma mark Device Controller

/**
 * Setup Device Controller
 */
- (void)setupController
{
	// Serviceを一つ選択する
	_service = [_services objectAtIndex:0];
	
	// create the device controller
	[self createDeviceControllerWithService:_service];
}

/**
 * Create Device Controller
 */
- (void)createDeviceControllerWithService:(ARService*)service
{
	// first get a discovery device
	ARDISCOVERY_Device_t * discoveryDevice = [self createDiscoveryDeviceWithService:service];
	
	if(discoveryDevice != NULL)
	{
		eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
		
		printlog(@"- ARCONTROLLER_Device_New ... ");
		
		// create the device controller
		_deviceController = ARCONTROLLER_Device_New(discoveryDevice, &error);
		
		// Error
		if ((error != ARCONTROLLER_OK) || (_deviceController == NULL))
		{
			printlog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
		}
		
		// add the state change callback to be informed when the device controller starts, stops...
		if (error == ARCONTROLLER_OK)
		{
			printlog(@"- ARCONTROLLER_Device_AddStateChangedCallback ... ");
			error = ARCONTROLLER_Device_AddStateChangedCallback(_deviceController, stateChanged, (__bridge void *)(self));
			
			// Error
			if (error != ARCONTROLLER_OK)
			{
				printlog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
		}
		
		// add the command received callback to be informed when a command has been received from the device
		if (error == ARCONTROLLER_OK)
		{
			printlog(@"- ARCONTROLLER_Device_AddCommandRecievedCallback ... ");
			error = ARCONTROLLER_Device_AddCommandReceivedCallback(_deviceController, onCommandReceived, (__bridge void *)(self));
			
			// Error
			if (error != ARCONTROLLER_OK)
			{
				printlog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
		}
		
		// start the device controller (the callback stateChanged should be called soon)
		if (error == ARCONTROLLER_OK)
		{
			printlog(@"- ARCONTROLLER_Device_Start ... ");
			error = ARCONTROLLER_Device_Start(_deviceController);
			
			// Error
			if (error != ARCONTROLLER_OK)
			{
				printlog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
		}
		
		// we don't need the discovery device anymore
		ARDISCOVERY_Device_Delete(&discoveryDevice);
		
		// if an error occured, go back
		if (error != ARCONTROLLER_OK)
		{
			[self resetController];
		}
		// Everything is OK
		else {
			_isReady = YES;
			if( [self.delegate respondsToSelector:@selector(rsManagerIsReady:)] ) {
				[self.delegate rsManagerIsReady:self];
			}
		}
	}
}
/**
 * Create Device
 */
- (ARDISCOVERY_Device_t *)createDiscoveryDeviceWithService:(ARService*)service
{
	printlog(@"createDiscoveryDeviceWithService");
	printlog(@"- init discovey device  ... ");
	
	ARDISCOVERY_Device_t *device = NULL;
	eARDISCOVERY_ERROR errorDiscovery = ARDISCOVERY_OK;
	
	// デバイスを生成
	device = ARDISCOVERY_Device_New(&errorDiscovery);
	
	// Error
	if ((errorDiscovery != ARDISCOVERY_OK) || (device == NULL))
	{
		printlog(@"device : %p", device);
		printlog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
	}
	
	// Success
	if (errorDiscovery == ARDISCOVERY_OK)
	{
		// get the ble service from the ARService
		ARBLEService* bleService = service.service;
		
		// create a RollingSpider discovery device (ARDISCOVERY_PRODUCT_MINIDRONE)
		errorDiscovery = ARDISCOVERY_Device_InitBLE(device, ARDISCOVERY_PRODUCT_MINIDRONE, (__bridge ARNETWORKAL_BLEDeviceManager_t)(bleService.centralManager), (__bridge ARNETWORKAL_BLEDevice_t)(bleService.peripheral));
		
		// Error
		if (errorDiscovery != ARDISCOVERY_OK)
		{
			printlog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
		}
	}
	
	return device;
}
/**
 * Reset Device Controller
 */
- (void)resetController
{
	printlog(@"resetController // disconnecting...");
	
	_isReady = NO;
	
	// in background
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
		
		// if the device controller is not stopped, stop it
		eARCONTROLLER_DEVICE_STATE state = ARCONTROLLER_Device_GetState(_deviceController, &error);
		if ((error == ARCONTROLLER_OK) && (state != ARCONTROLLER_DEVICE_STATE_STOPPED))
		{
			// after that, stateChanged should be called soon
			error = ARCONTROLLER_Device_Stop (_deviceController);
			
			if (error != ARCONTROLLER_OK)
			{
				printlog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
			else
			{
				// wait for the state to change to stopped
				printlog(@"- wait new state ... ");
				dispatch_semaphore_wait(_stateSem, DISPATCH_TIME_FOREVER);
			}
		}
		
		// once the device controller is stopped, we can delete it
		if (_deviceController != NULL)
		{
			ARCONTROLLER_Device_Delete(&_deviceController);
		}
		
		// dismiss the alert view in main thread
		dispatch_async(dispatch_get_main_queue(), ^{
			printlog(@"disconnected.");
			
			if( [self.delegate respondsToSelector:@selector(rsManagerDidDisconnected:)] ) {
				[self.delegate rsManagerDidDisconnected:self];
			}
			
		});
	});
}


#pragma mark Device controller callbacks

/**
 * State Changed
 * called when the state of the device controller has changed
 */
void stateChanged (eARCONTROLLER_DEVICE_STATE newState, eARCONTROLLER_ERROR error, void *customData)
{
	//PilotingViewController *pilotingViewController = (__bridge PilotingViewController *)customData;
	RSManager * this = (__bridge RSManager *)customData;
	
	printlog (@"newState: %d",newState);
	
	if (this != nil)
	{
		switch (newState)
		{
			case ARCONTROLLER_DEVICE_STATE_RUNNING:
			{
				// dismiss the alert view in main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					if( [this.delegate respondsToSelector:@selector(rsManagerDeviceStateRunning:)] ) {
						[this.delegate rsManagerDeviceStateRunning:this];
					}
				});
				break;
			}
			case ARCONTROLLER_DEVICE_STATE_STOPPED:
			{
				dispatch_semaphore_signal(this.stateSem);
				
				// Go back
				dispatch_async(dispatch_get_main_queue(), ^{
					// Reset Controller
					[this resetController];
				});
				
				break;
			}
				
			case ARCONTROLLER_DEVICE_STATE_STARTING:
				break;
				
			case ARCONTROLLER_DEVICE_STATE_STOPPING:
				break;
				
			default:
				printlog(@"new State : %d not known", newState);
				break;
		}
	}
}
/**
 * Command Received
 * called when a command has been received from the drone
 */
void onCommandReceived (eARCONTROLLER_DICTIONARY_KEY commandKey, ARCONTROLLER_DICTIONARY_ELEMENT_t *elementDictionary, void *customData)
{
//	PilotingViewController *pilotingViewController = (__bridge PilotingViewController *)customData;
	RSManager * this = (__bridge RSManager *)customData;
	
	// if the command received is a battery state changed
	if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED) && (elementDictionary != NULL))
	{
		ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
		ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
		
		// get the command received in the device controller
		HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
		if (element != NULL)
		{
			// get the value
			HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED_PERCENT, arg);
			
			if (arg != NULL)
			{
				// update UI
				[this onUpdateBatteryLevel:arg->value.U8];
			}
		}
	}
}
/**
 * on update Battery Level
 */
- (void)onUpdateBatteryLevel:(uint8_t)percent
{
	printlog(@"onUpdateBatteryLevel // batteryLevel=%d", percent);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		if( [self.delegate respondsToSelector:@selector(rsManagerOnUpdateBatteryLevel:percentage:)] ) {
			[self.delegate rsManagerOnUpdateBatteryLevel:self percentage:percent];
		}
	});
}

//////////////////////////////////////////////////
#pragma mark - Commands
//////////////////////////////////////////////////

/**
 * Takeoff / Landing
 */
- (void)emergency
{
	printlog(@"emergency");
	_deviceController->miniDrone->sendPilotingEmergency(_deviceController->miniDrone);
}
- (void)takeoff
{
	printlog(@"takeoff");
	_deviceController->miniDrone->sendPilotingTakeOff(_deviceController->miniDrone);
}
- (void)landing
{
	printlog(@"landing");
	_deviceController->miniDrone->sendPilotingLanding(_deviceController->miniDrone);
}

/**
 * Gaz
 */
- (void)gazUpStart
{
	_deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, 50);
}
- (void)gazDownStart
{
	_deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, -50);
}
- (void)gazEnd
{
	_deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, 0);
}

/**
 * Yaw
 */
- (void)yawLeftStart
{
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, -50);
}
- (void)yawRightStart
{
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, 50);
}
- (void)setYawSpeedPercentage:(int8_t)percentage
{
	// -100 to 100
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, percentage);
}
- (void)yawEnd
{
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, 0);
}

/**
 * Roll
 */
- (void)rollLeftStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, -50);
}
- (void)rollRightStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 50);
}
- (void)setRollAnglePercentage:(int8_t)percentage
{
	printlog(@"setRollAnglePercentage // percentage=%d", percentage);
	// -100 to 100
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, percentage);
}
- (void)rollEnd
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 0);
}

/**
 * Pitch
 */
- (void)pitchForwardStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 50);
}
- (void)pitchBackStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, -50);
}
- (void)setPitchAnglePercentage:(int8_t)percentage
{
	printlog(@"setPitchAnglePercentage // percentage=%d", percentage);
	// -100 to 100
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, percentage);
}
- (void)pitchEnd
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 0);
}

/**
 * Steering
 */
- (void)steeringStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 0);
}
- (void)steeringEnd
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 0);
	
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 0);
}

/**
 * Flip
 */
- (void)flipFront
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_FRONT);
}
- (void)flipBack
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_BACK);
}
- (void)flipRight
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_RIGHT);
}
- (void)flipLeft
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_LEFT);
}

/**
 * Picture
 */
- (void)takepicture
{
	_deviceController->miniDrone->sendMediaRecordPicture(_deviceController->miniDrone, 0);
}


@end
