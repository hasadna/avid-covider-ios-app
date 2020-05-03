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
    
    private static let center = UNUserNotificationCenter.current()
    
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
        
    static func createReminderRequest(dateComponents: DateComponents) -> UNNotificationRequest {
        let identifier = UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = .reminder_notification_title
        content.body = .reminder_notification_body
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        return .init(identifier: identifier,
                     content: content,
                     trigger: trigger)
    }
    
    static func schedule(request: UNNotificationRequest) -> Completable {
        .create { observer in
            center.add(request) { error in
                if let error = error {
                    observer(.error(error))
                } else {
                    observer(.completed)
                }
            }
            
            return Disposables.create()
        }
    }
        
    static func unschedule(request: UNNotificationRequest) -> Completable {
        .create { observer in
            center.removeDeliveredNotifications(withIdentifiers: [request.identifier])
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
            
            observer(.completed)
            
            return Disposables.create()
        }
    }
    
}
