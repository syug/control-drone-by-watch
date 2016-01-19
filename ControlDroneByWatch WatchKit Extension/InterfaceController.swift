//
//  InterfaceController.swift
//  ControlDroneByWatch WatchKit Extension
//
//  Created by Syugo Saito on 2015/12/10.
//  Copyright © 2015年 Syugo Saito. All rights reserved.
//

import WatchKit
import Foundation
import CoreMotion
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate {
	
	@IBOutlet var labelX: WKInterfaceLabel!
	@IBOutlet var labelY: WKInterfaceLabel!
	@IBOutlet var labelZ: WKInterfaceLabel!
	
	@IBOutlet var labelYaw: WKInterfaceLabel!
	@IBOutlet var labelRoll: WKInterfaceLabel!
	@IBOutlet var labelPitch: WKInterfaceLabel!
	
	let motionManager = CMMotionManager()
	
	
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
		motionManager.accelerometerUpdateInterval = 0.1
		
		if (WCSession.isSupported()) {
			let session = WCSession.defaultSession()
			session.delegate = self // conforms to WCSessionDelegate
			session.activateSession()
		}
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
		
		if (motionManager.accelerometerAvailable == true) {
			let handler:CMAccelerometerHandler = {(data: CMAccelerometerData?, error: NSError?) -> Void in
				self.labelX.setText(String(format: "%.2f", data!.acceleration.x))
				self.labelY.setText(String(format: "%.2f", data!.acceleration.y))
				self.labelZ.setText(String(format: "%.2f", data!.acceleration.z))
				//self.sendDataToPhone(data!.acceleration)
				self.checkCurrentPose( data!.acceleration )
			}
			motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: handler)
		}
		else {
			self.labelX.setText("not available")
			self.labelY.setText("not available")
			self.labelZ.setText("not available")
		}
    }

    override func didDeactivate() {
        super.didDeactivate()
		
		motionManager.stopAccelerometerUpdates()
    }
	
	
	// =========================================================================
	// MARK: - Btn Events
	// =========================================================================
	
	/**
	 *
	 */
	@IBAction func tapStickBtn() {
		if lock { return }
		
		let isSteering = !steering
		
		if isSteering {
			stickBtn.setBackgroundImageNamed("stick-on2.png")
			sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.SteeringStart.rawValue])
		}
		else {
			stickBtn.setBackgroundImageNamed("stick-off2.png")
			sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.SteeringEnd.rawValue])
		}
		
		steering = isSteering
	}
	@IBOutlet var stickBtn: WKInterfaceButton!
	
	/**
	 *
	 */
	@IBAction func tapLockBtn() {
		lock = !lock
		
		standby = false
		
		if lock {
			lockbtn.setBackgroundImageNamed("btn-lock.png")
		}
		else {
			lockbtn.setBackgroundImageNamed("btn-unlock.png")
		}
	}
	@IBOutlet var lockbtn: WKInterfaceButton!
	
	
	@IBAction func tapCamBtn() {
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.TakePicture.rawValue])
	}
	@IBAction func tapEmergencyBtn() {
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.Emergency.rawValue])
	}
	
	
	// MARK: Menu Btns
	@IBAction func tapFrontFlipBtn() {
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.FlipFront.rawValue])
	}
	@IBAction func tapBackFlipBtn() {
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.FlipBack.rawValue])
	}
	
	@IBAction func tapRightFlipBtn() {
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.FlipRight.rawValue])
	}
	
	@IBAction func tapLefttFlipBtn() {
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.FlipLeft.rawValue])
	}
	
	
	// =========================================================================
	// MARK: - Acceleration
	// =========================================================================
	
//	enum WatchAltitude: Int {
//		case Default
//		case Standby
//		
//		case Takeoff
//		case Landing
//		case Emergency
//		
//		case YawRight
//		case YawLeft
//		case YawCenter
//		case Up
//		case Down
//	}
	
	var lock: Bool = false
	var standby: Bool = false
	var flying: Bool = false
	var steering: Bool = false
	//var hovering: Bool = false
	
	var state_yaw: ARCommand? = nil
	var state_gaz: ARCommand? = nil
	var state_roll: ARCommand? = ARCommand.RollEnd
	var state_pitch: ARCommand? = ARCommand.PitchEnd
	
	/**
	 *
	 */
	func checkCurrentPose(acc: CMAcceleration) {
		//let yaw = atan2(acc.x, acc.y)	// Y軸を起点にしたいので、Xを縦軸/Yを横軸に
		//let roll = atan2(acc.z, acc.x)
		let yaw = getAltitude(acc.x, h_axis: acc.y)	// Y軸を起点にしたいので、Xを縦軸/Yを横軸に
		let roll = getAltitude(acc.z, h_axis: acc.x)
		let pitch = getAltitude(acc.z, h_axis: acc.y)
		
		let y_deg = rad2deg( yaw )
		let r_deg = rad2deg( roll )
		let p_deg = rad2deg( pitch )
		labelYaw.setText( String(format: "%.1f", y_deg) )
		labelRoll.setText( String(format: "%.1f", r_deg) )
		labelPitch.setText( String(format: "%.1f", p_deg) )
		
		// ロック
		if lock { return }
		
		// 一度手を下ろした状態で Standby とする
		if !standby {
			if r_deg > -100.0 && r_deg < -80.0 {
				standby = true
			}
		} else {
			
			// Flying State
			if r_deg > -10.0 && r_deg < 10.0 {
				if !flying {
					flying = true
					sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.Takeoff.rawValue])
				}
				//setState( WatchAltitude.Takeoff )
			} else if r_deg > -100.0 && r_deg < -80.0 {
				if flying {
					flying = false
					sendMessageToPhone(["type":MessageType.Command.rawValue, "command": ARCommand.Landing.rawValue])
				}
			}
			
			if flying {
				
				// ホバリング状態
				if !steering {
					// Yaw
					if p_deg > 30 {
						setStateYaw( ARCommand.YawRight )
					} else if p_deg < -30 {
						setStateYaw( ARCommand.YawLeft )
					} else {
						setStateYaw( ARCommand.YawEnd )
					}
					// Gaz
					if r_deg > 30 {
						setStateGaz( ARCommand.GazUp )
					} else if r_deg < -30 && r_deg > -80 {
						setStateGaz( ARCommand.GazDown )
					} else if r_deg < 30 && r_deg > -30 {
						setStateGaz( ARCommand.GazEnd )
					}
				}
				// ステアリング状態
				else {
					// 実機のPitchは rollの逆数 に、Rollは pitch に対応。
					//sendMessageToPhone(["type":MessageType.Altitude.rawValue, "pitch":-r_deg, "roll":p_deg])
					//sendMessageToPhone(["type":MessageType.Altitude.rawValue, "pitch":rad2per(-roll), "roll":rad2per(pitch)])
					
					
					// Yaw
					if p_deg > 30 {
						setStateRoll( ARCommand.RollRight )
					} else if p_deg < -30 {
						setStateRoll( ARCommand.RollLeft )
					} else {
						setStateRoll( ARCommand.RollEnd )
					}
					// Gaz
					if r_deg > 30 {
						setStatePitch( ARCommand.PitchBackward )
					} else if r_deg < -30 && r_deg > -80 {
						setStatePitch( ARCommand.PitchFoward )
					} else if r_deg < 30 && r_deg > -30 {
						setStatePitch( ARCommand.PitchEnd )
					}
				}
			}
		}
		
		print("standby=\(standby) flying=\(flying) steering=\(steering) // state_yaw=\(state_yaw) state_gaz=\(state_gaz)")
	}
	func getAltitude(v_axis:Double, h_axis:Double) -> Double {
		// 実機の向きをフェイスが上=0とすると、重力加速度の向きに対して、実機の向きは90度ずれ & 逆回転
		let v = h_axis * -1.0
		let h = v_axis * -1.0
		return atan2(v, h)
	}
	func rad2deg(rad: Double) -> Double {
		return 180*rad/M_PI
	}
	func rad2per(rad: Double) -> Int {
		let d = round( (rad/M_PI_2)*100 )
		return Int(d)
	}
	
	
	func setStateYaw(val: ARCommand) {
		if state_yaw == val { return }
		state_yaw = val
		print("***** change yaw state!!! state_yaw=\(state_yaw) rawValue=\(state_yaw?.rawValue)")
		
		// Phoneに送信する
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": state_yaw!.rawValue])
	}
	func setStateGaz(val: ARCommand) {
		if state_gaz == val { return }
		state_gaz = val
		print("***** change gaz state!!! state_gaz=\(state_gaz) rawValue=\(state_gaz?.rawValue)")
		
		// Phoneに送信する
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": state_gaz!.rawValue])
	}
	
	func setStateRoll(val: ARCommand) {
		if state_roll == val { return }
		state_roll = val
		// Phoneに送信する
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": state_roll!.rawValue])
	}
	func setStatePitch(val: ARCommand) {
		if state_pitch == val { return }
		state_pitch = val
		// Phoneに送信する
		sendMessageToPhone(["type":MessageType.Command.rawValue, "command": state_pitch!.rawValue])
	}
	
	
	// =========================================================================
	// MARK: - WCSession
	// =========================================================================
	
	func sendMessageToPhone(message: [String: AnyObject]) {
		
		WCSession.defaultSession().sendMessage(
			message, replyHandler: { (replyMessage) -> Void in
				//
			}) { (error) -> Void in
				print(error.localizedDescription)
		}
	}
	func sendDataToPhone(acc: CMAcceleration) {
		let message = ["x": acc.x, "y": acc.y, "z": acc.z]
		
		WCSession.defaultSession().sendMessage(
			message, replyHandler: { (replyMessage) -> Void in
				//
			}) { (error) -> Void in
				print(error.localizedDescription)
		}
	}
	
	// MARK: WCSessionDelegate
	
	func sessionWatchStateDidChange(session: WCSession) {
		print(__FUNCTION__)
		print(session)
		print("reachable:\(session.reachable)")
	}
	
	// Received message from iPhone
	func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
		print(__FUNCTION__)
		guard message["request"] as? String == "showAlert" else {return}
		
		let defaultAction = WKAlertAction(
			title: "OK",
			style: WKAlertActionStyle.Default) { () -> Void in
		}
		let actions = [defaultAction]
		
		self.presentAlertControllerWithTitle(
			"Message Received",
			message: "",
			preferredStyle: WKAlertControllerStyle.Alert,
			actions: actions)
	}

}
