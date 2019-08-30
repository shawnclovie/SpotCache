//
//  AppDelegate.swift
//  SpotCacheTestApp
//
//  Created by Shawn Clovie on 30/8/2019.
//  Copyright © 2019 Spotlit.club. All rights reserved.
//

import UIKit
import Spot
import SpotCache

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		
		Log.Level.spotcache = .trace
		
		let window = UIWindow(frame: UIScreen.main.bounds)
		self.window = window
		window.rootViewController = UINavigationController(rootViewController: ViewController(nibName: nil, bundle: nil))
		window.makeKeyAndVisible()
		return true
	}
}
