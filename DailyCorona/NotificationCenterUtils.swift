//
//  NotificationCenterUtils.swift
//  DailyCorona
//
//  Created by Adar Hefer on 30/04/2020.
//  Copyright © 2020 Adar Hefer. All rights reserved.
//

import UserNotifications
import RxSwift

class NotificationCenterUtils {
    
    static let center = UNUserNotificationCenter.current()
    
    static func getNotificationSettings() -> Single<UNNotificationSettings> {
        .create { observer in
            center.getNotificationSettings { settings in
                observer(.success(settings))
            }
            
            return Disposables.create()
        }
    }
    
    static func requestAuthorization(options: UNAuthorizationOptions) -> Single<Bool> {
        .create { observer in
            center.requestAuthorization(options: options) { success, error in
                if let error = error {
                    observer(.error(error))
                } else {
                    observer(.success(success))
                }
            }
            
            return Disposables.create()
        }
    }
    
}
