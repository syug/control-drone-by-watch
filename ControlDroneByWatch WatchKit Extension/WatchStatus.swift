//
//  WatchStatus.swift
//  ControlDroneByWatch
//
//  Created by Syugo Saito on 2015/12/14.
//  Copyright © 2015年 Syugo Saito. All rights reserved.
//

import Foundation

class WatchStatus {
	
	init() {
		
	}
	
	
	
}

enum MessageType: Int {
	case Command
	case Altitude
}
enum ARCommand: Int {
	case Takeoff
	case Landing
	case Emergency
	
	case GazUp
	case GazDown
	case GazEnd
	
	case YawRight
	case YawLeft
	case YawEnd
	
	case RollRight
	case RollLeft
	case RollEnd
	
	case PitchFoward
	case PitchBackward
	case PitchEnd
	
	case SteeringStart
	case SteeringEnd
	
	case FlipFront
	case FlipBack
	case FlipRight
	case FlipLeft
	
	case TakePicture
}