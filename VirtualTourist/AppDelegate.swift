//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    let stack = CoreDataStack(modelName: "VirtualTourist")!
    
    func preloadData() {
        // Remove previous data (if any)
        do {
            try stack.dropAllData()
        } catch {
            print("Error droping all objects in DB")
        } 
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        stack.save()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        stack.save()
    }
}
