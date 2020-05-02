//
//  AppDelegate.swift
//  DailyCorona
//
//  Created by Adar Hefer on 29/04/2020.
//  Copyright © 2020 Adar Hefer. All rights reserved.
//

import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        _ = DataManager.shared.setup().subscribe()
        
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        _ = DataManager.shared.refreshNotificationSettings().subscribe()
    }
    
    // MARK: UISceneSession Lifecycle
    @available(iOS 13, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}


extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        _ = DataManager.shared.openSurvey()
            .do(onDispose: {
                completionHandler()
            })
            .subscribe()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        _ = DataManager.shared.updateReminder()
            .do(onDispose: {
                completionHandler(UNNotificationPresentationOptions(rawValue: 0))
            })
            .subscribe()
    }
}
