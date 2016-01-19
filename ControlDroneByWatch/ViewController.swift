//
//  ViewController.swift
//  ControlDroneByWatch
//
//  Created by Syugo Saito on 2015/12/10.
//  Copyright © 2015年 Syugo Saito. All rights reserved.
//

import UIKit
import Foundation
import WatchConnectivity

class ViewController: UIViewController, WCSessionDelegate, RSManagerDelegate {
	
	// =========================================================================
	//
	var manager: RSManager = RSManager()
	var wa: WatchStatus = WatchStatus()
	let alert: UIAlertController! = UIAlertController(title: nil, message: "msg", preferredStyle: UIAlertControllerStyle.Alert)
	
	@IBOutlet weak var img: UIImageView!
	//var img: UIImageView = UIImageView(frame: CGRectMake(236, 302, 125, 125))
	
	
	// =========================================================================
	// MARK: - View Lifecycle
	// =========================================================================
	
	override func viewDidLoad() {
		print(__FUNCTION__)
		
		img.image = nil
		manager.initialize()
		manager.delegate = self
		
		super.viewDidLoad()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	override func viewWillAppear(animated: Bool) {
		print(__FUNCTION__)
		startSession()
	}
	override func viewDidAppear(animated: Bool) {
		print(__FUNCTION__)
		manager.startDiscovery()
	}
	override func viewWillDisappear(animated: Bool) {
		print(__FUNCTION__)
		manager.stopDiscovery()
	}
	
	
	// =========================================================================
	// MARK: - Btn
	// =========================================================================
	
	@IBAction func btnTapped(sender: UIButton) {
		print("btnTapped // tag=\(sender.tag)")
		
		if !manager.isReady { return }
		
		switch sender.tag {
			
		case 0:
			manager.takeoff()
		case 1:
			manager.landing()
		case 2:
			manager.takepicture()
		case 3:
			manager.emergency()
		default:
			manager.emergency()
			manager.stopConnecting()
		}
	}
	@IBAction func restartBtnTapped(sender: AnyObject) {
		startSession()
	}
	@IBAction func connectBtnTapped(sender: AnyObject) {
		if manager.isReady { manager.startConnecting() }
	}
	@IBAction func disconnectBtnTapped(sender: AnyObject) {
		if manager.isReady { manager.stopConnecting() }
	}
	
	
	// =========================================================================
	// MARK: - WCSession
	// =========================================================================
	
	func startSession() {
		print("startSession // WCSession.isSupported()=\(WCSession.isSupported())")
		
		if (WCSession.isSupported()) {
			let session = WCSession.defaultSession()
			session.delegate = self
			session.activateSession()
		}
	}
	
	
	// MARK: WCSessionDelegate
	
	func sessionWatchAltitudeDidChange(session: WCSession) {
		print("\(__FUNCTION__) // session=\(session) reachable:\(session.reachable)")
	}
	
	func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
		print("\(__FUNCTION__) // MESSAGE RECEIVED // message['type']=\(message["type"])")
		
		if let typeNum = message["type"] as? Int {
			let type = MessageType(rawValue: typeNum)
			
			if type==MessageType.Command {
				
				if let numCommand:Int = message["command"] as? Int {
					if let command = ARCommand(rawValue: numCommand) {
						// Commandを処理
						handleCommand(command)
						// Commandを表示
						dispatch_async(dispatch_get_main_queue()) { () -> Void in
							self.setCommandImage( command )
						}
					}
				}
				
			}
			else if type==MessageType.Altitude {
				let numRoll: Int = message["roll"] as! Int
				let numPitch: Int = message["pitch"] as! Int
				handleAltitude(numRoll, pitch: numPitch)
			}
		}
	}
	
	func handleCommand(command: ARCommand) {
		print("command=\(command)")
		
		if !manager.isReady { return }
		
		switch command {
		case .Takeoff:			manager.takeoff()
		case .Landing:			manager.landing()
		case .Emergency:		manager.emergency()
			
		case .GazEnd:			manager.gazEnd()
		case .GazUp:			manager.gazUpStart()
		case .GazDown:			manager.gazDownStart()
			
		case .YawEnd:			manager.yawEnd()
		case .YawLeft:			manager.yawLeftStart()
		case .YawRight:			manager.yawRightStart()
			
		case .RollEnd:			manager.rollEnd()
		case .RollLeft:			manager.rollLeftStart()
		case .RollRight:		manager.rollRightStart()
			
		case .PitchEnd:			manager.pitchEnd()
		case .PitchFoward:		manager.pitchForwardStart()
		case .PitchBackward:	manager.pitchBackStart()
			
		case .SteeringStart:	manager.steeringStart()
		case .SteeringEnd:		manager.steeringEnd()
			
		case .FlipFront:		manager.flipFront()
		case .FlipBack:			manager.flipBack()
		case .FlipRight:		manager.flipRight()
		case .FlipLeft:			manager.flipLeft()
			
		case .TakePicture:		manager.takepicture()
		}
	}
	func handleAltitude(roll: Int, pitch: Int) {
		print("handleAltitude // roll=\(roll) pitch=\(pitch)")
		
		if !manager.isReady { return }
		manager.setRollAnglePercentage(Int8(roll))
		manager.setPitchAnglePercentage(Int8(pitch))
	}
	
	
	func setCommandImage(command: ARCommand) {
		let n = command.rawValue
		let names = [
			"cmd-takeoff",
			"cmd-landing",
			"cmd-emergency",
			
			"cmd-gaz0",
			"cmd-gaz1",
			"cmd-gaz2",
			"cmd-yaw0",
			"cmd-yaw1",
			"cmd-yaw2",
			"cmd-roll0",
			"cmd-roll1",
			"cmd-roll2",
			"cmd-pitch0",
			"cmd-pitch1",
			"cmd-pitch2",
			
			"cmd-steering0",
			"cmd-steering1",
			
			"cmd-flip",
			"cmd-flip",
			"cmd-flip",
			"cmd-flip",
			
			"cmd-picture"
		]
		
		if n<names.count {
			let name = "\(names[n]).png"
			img.image = UIImage(named: name)
			
			self.img.transform = CGAffineTransformMakeScale(0.9, 0.9)
			self.img.alpha = 0.5
			UIView.animateWithDuration(0.4, animations: { () -> Void in
				self.img.transform = CGAffineTransformMakeScale(1, 1)
				self.img.alpha = 1.0;
				}, completion: { (Bool) -> Void in
					
				}
			)
			
			
		} else {
			img.image = nil
		}
	}
	
	// =========================================================================
	// MARK: - RSManagerDelegate
	// =========================================================================
	
	func rsManagerDidStartDiscovery(manager: RSManager!) {
		print(__FUNCTION__)
		alert.message = "Searching..."
		presentViewController(alert, animated: true, completion: nil)
	}
	func rsManagerDidStopDiscovery(manager: RSManager!) {
		dismissViewControllerAnimated(false, completion: nil)
	}
	//
	func rsManagerDidStartConnecting(manager: RSManager!) {
		alert.message = "Connecting..."
		presentViewController(alert, animated: true, completion: nil)
	}
	func rsManagerDidStopConnecting(manager: RSManager!) {
		alert.message = "Disconnecting..."
		presentViewController(alert, animated: true, completion: nil)
	}
	func rsManagerDidDisconnected(manager: RSManager!) {
		alert.message = "Disconnected."
		presentViewController(alert, animated: true, completion: nil)
	}
	//
	func rsManagerIsReady(manager: RSManager!) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	func rsManagerDeviceStateRunning(manager: RSManager!) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	func rsManagerOnUpdateBatteryLevel(manager: RSManager!, percentage: UInt8) {
		//
	}
	
}