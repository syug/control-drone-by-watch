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
@property (nonatomic, strong) UIAlertView * alertView;
@property (nonatomic) dispatch_semaphore_t stateSem;
@property (nonatomic, strong) ARService * service;

@end


@implementation RSManager

-(void) initialize {
	NSLog(@"RSManager // Initialize");
	_services = [NSArray array];
	_deviceController = NULL;
	_stateSem = dispatch_semaphore_create(0);
	_isReady = NO;
	
	self.alertView = [[UIAlertView alloc] initWithTitle:nil message:@"Connecting ..."
										   delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
}


/**
 * DISCOVERY DEVICES
 */
#pragma mark - Discovery

-(void) startDiscovery {
	
	// Add Notification
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidUpdateServices:) name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
	
	// start the discovery
	[[ARDiscovery sharedInstance] start];
	
	if( self.alertView ) {
		self.alertView.message = @"Searching...";
		[self.alertView show];
	}
}
-(void) stopDiscovery {
	// Remove Notification
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
	
	// stop discovery
	[[ARDiscovery sharedInstance] stop];
	
	if( self.alertView ) {
		[self.alertView dismissWithClickedButtonIndex:0 animated:NO];
	}
}

#pragma mark ARDiscovery notification

- (void) discoveryDidUpdateServices:(NSNotification *)notification
{
	// Called when the list of discovered services has changed
	dispatch_async(dispatch_get_main_queue(), ^{
		[self updateServicesList:[[notification userInfo] objectForKey:kARDiscoveryServicesList]];
	});
}

- (void) updateServicesList:(NSArray *)services
{
	NSMutableArray * serviceArray = [NSMutableArray array];
	
	for (ARService * service in services)
	{
		// only display the ble services
		if ([service.service isKindOfClass:[ARBLEService class]])
		{
			[serviceArray addObject:service];
		}
	}
	
	_services = serviceArray;
	
	// AUTO CONNECT
	if (_services.count>0) {
		[self connect];
	}
}

-(void) connect {
	if( self.alertView ) {
		self.alertView.message = @"Connecting...";
		if( !self.alertView.isHidden ) {
			[self.alertView show];
		}
	}
	
	[self stopDiscovery];
	[self setupController];
}

-(void) disconnect {
	[self stopDiscovery];
	[self resetController];
	
	if( self.alertView ) {
		//[self.alertView dismissWithClickedButtonIndex:0 animated:NO];
		self.alertView.message = @"Disconnecting...";
		if( !self.alertView.isHidden ) {
			[self.alertView show];
		}
	}
}


/**
 * CONTROL DEVICE
 */
- (void) setupController
{
	// Serviceを一つ選択する
	_service = [_services objectAtIndex:0];
	
	// create the device controller
	[self createDeviceControllerWithService:_service];
}

- (ARDISCOVERY_Device_t *)createDiscoveryDeviceWithService:(ARService*)service
{
	ARDISCOVERY_Device_t *device = NULL;
	eARDISCOVERY_ERROR errorDiscovery = ARDISCOVERY_OK;
	
	NSLog(@"- init discovey device  ... ");
	
	device = ARDISCOVERY_Device_New (&errorDiscovery);
	if ((errorDiscovery != ARDISCOVERY_OK) || (device == NULL))
	{
		NSLog(@"device : %p", device);
		NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
	}
	
	if (errorDiscovery == ARDISCOVERY_OK)
	{
		// get the ble service from the ARService
		ARBLEService* bleService = service.service;
		
		// create a RollingSpider discovery device (ARDISCOVERY_PRODUCT_MINIDRONE)
		errorDiscovery = ARDISCOVERY_Device_InitBLE (device, ARDISCOVERY_PRODUCT_MINIDRONE, (__bridge ARNETWORKAL_BLEDeviceManager_t)(bleService.centralManager), (__bridge ARNETWORKAL_BLEDevice_t)(bleService.peripheral));
		
		if (errorDiscovery != ARDISCOVERY_OK)
		{
			NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
		}
	}
	
	return device;
}

- (void) createDeviceControllerWithService:(ARService*)service
{
	// first get a discovery device
	ARDISCOVERY_Device_t *discoveryDevice = [self createDiscoveryDeviceWithService:service];
	
	if (discoveryDevice != NULL)
	{
		eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
		
		// create the device controller
		NSLog(@"- ARCONTROLLER_Device_New ... ");
		_deviceController = ARCONTROLLER_Device_New (discoveryDevice, &error);
		
		if ((error != ARCONTROLLER_OK) || (_deviceController == NULL))
		{
			NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
		}
		
		// add the state change callback to be informed when the device controller starts, stops...
		if (error == ARCONTROLLER_OK)
		{
			NSLog(@"- ARCONTROLLER_Device_AddStateChangedCallback ... ");
			error = ARCONTROLLER_Device_AddStateChangedCallback(_deviceController, stateChanged, (__bridge void *)(self));
			
			if (error != ARCONTROLLER_OK)
			{
				NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
		}
		
		// add the command received callback to be informed when a command has been received from the device
		if (error == ARCONTROLLER_OK)
		{
			NSLog(@"- ARCONTROLLER_Device_AddCommandRecievedCallback ... ");
			error = ARCONTROLLER_Device_AddCommandReceivedCallback(_deviceController, onCommandReceived, (__bridge void *)(self));
			
			if (error != ARCONTROLLER_OK)
			{
				NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
		}
		
		// start the device controller (the callback stateChanged should be called soon)
		if (error == ARCONTROLLER_OK)
		{
			NSLog(@"- ARCONTROLLER_Device_Start ... ");
			error = ARCONTROLLER_Device_Start (_deviceController);
			
			if (error != ARCONTROLLER_OK)
			{
				NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
		}
		
		// we don't need the discovery device anymore
		ARDISCOVERY_Device_Delete (&discoveryDevice);
		
		// if an error occured, go back
		if (error != ARCONTROLLER_OK)
		{
			_isReady = NO;
			[self goBack];
		} else {
			_isReady = YES;
			if( self.alertView ) {
				[self.alertView dismissWithClickedButtonIndex:0 animated:YES];
			}
		}
	}
}

- (void) resetController
{
	NSLog(@"resetController // disconnecting...");
	_isReady = NO;
	
	if( self.alertView ) {
		[self.alertView dismissWithClickedButtonIndex:0 animated:NO];
		self.alertView.message = @"Disconnecting...";
		[self.alertView show];
	}
	
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
				NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
			}
			else
			{
				// wait for the state to change to stopped
				NSLog(@"- wait new state ... ");
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
			[self.alertView dismissWithClickedButtonIndex:0 animated:YES];
			NSLog(@"disconnected.");
		});
	});
}

- (void) goBack
{
	NSLog(@"ERROR Occured. RESET Controller.");
	[self resetController];
	//[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark Device controller callbacks
// called when the state of the device controller has changed
void stateChanged (eARCONTROLLER_DEVICE_STATE newState, eARCONTROLLER_ERROR error, void *customData)
{
	//PilotingViewController *pilotingViewController = (__bridge PilotingViewController *)customData;
	RSManager * this = (__bridge RSManager *)customData;
	
	NSLog (@"newState: %d",newState);
	
	if (this != nil)
	{
		switch (newState)
		{
			case ARCONTROLLER_DEVICE_STATE_RUNNING:
			{
				// dismiss the alert view in main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					//[pilotingViewController.alertView dismissWithClickedButtonIndex:0 animated:TRUE];
				});
				break;
			}
			case ARCONTROLLER_DEVICE_STATE_STOPPED:
			{
				dispatch_semaphore_signal(this.stateSem);
				
				// Go back
				dispatch_async(dispatch_get_main_queue(), ^{
					[this goBack];
				});
				
				break;
			}
				
			case ARCONTROLLER_DEVICE_STATE_STARTING:
				break;
				
			case ARCONTROLLER_DEVICE_STATE_STOPPING:
				break;
				
			default:
				NSLog(@"new State : %d not known", newState);
				break;
		}
	}
}

// called when a command has been received from the drone
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


#pragma mark events

- (void) emergency
{
	NSLog(@"emergency");
	
	// send an emergency command to the RollingSpider
	_deviceController->miniDrone->sendPilotingEmergency(_deviceController->miniDrone);
}

- (void) takeoff
{
	NSLog(@"takeoff");
	
	_deviceController->miniDrone->sendPilotingTakeOff(_deviceController->miniDrone);
}

- (void) landing
{
	NSLog(@"landing");
	_deviceController->miniDrone->sendPilotingLanding(_deviceController->miniDrone);
}

//events for gaz:
- (void) gazUpStart
{
	// set the gaz value of the piloting command
	_deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, 50);
}
- (void) gazDownStart
{
	_deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, -50);
}
- (void) gazEnd
{
	_deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, 0);
}

//events for yaw:
- (void) yawLeftStart
{
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, -50);
}
- (void) yawRightStart
{
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, 50);
}
- (void) setYawSpeedPercentage:(int8_t)percentage
{
	// -100 to 100
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, percentage);
}
- (void) yawEnd
{
	_deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, 0);
}

//events for yaw:
- (void) rollLeftStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, -50);
}
- (void) rollRightStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 50);
}
- (void) setRollAnglePercentage:(int8_t)percentage
{
	NSLog(@"setRollAnglePercentage // percentage=%d", percentage);
	// -100 to 100
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, percentage);
}
- (void) rollEnd
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 0);
}

//events for pitch:
- (void) pitchForwardStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 50);
}
- (void) pitchBackStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, -50);
}
- (void) setPitchAnglePercentage:(int8_t)percentage
{
	NSLog(@"setPitchAnglePercentage // percentage=%d", percentage);
	// -100 to 100
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, percentage);
}
- (void) pitchEnd
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 0);
}

// Steering
- (void) steeringStart
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 1);
	
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 0);
}
- (void) steeringEnd
{
	_deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, 0);
	
	_deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, 0);
	_deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, 0);
}

// Flip
- (void) flipFront
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_FRONT);
}
- (void) flipBack
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_BACK);
}
- (void) flipRight
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_RIGHT);
}
- (void) flipLeft
{
	_deviceController->miniDrone->sendAnimationsFlip(_deviceController->miniDrone, ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_LEFT);
}

// Picture
- (void) takepicture
{
	_deviceController->miniDrone->sendMediaRecordPicture(_deviceController->miniDrone, 0);
}



#pragma mark UI updates from commands
- (void) onUpdateBatteryLevel:(uint8_t)percent;
{
	NSLog(@"onUpdateBattery ...");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString *text = [[NSString alloc] initWithFormat:@"%d%%", percent];
		NSLog(@"batteryLevel = %@", text);
		//[_batteryLabel setText:text];
	});
}

@end
