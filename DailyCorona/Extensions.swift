//
//  Extensions.swift
//  CourseQuery
//
//  Created by Adar Hefer on 28/08/2019.
//  Copyright © 2019 Adar Hefer. All rights reserved.
//

import UIKit
import RxSwift
import CoreData

extension String {
        
    static let title = "title".localized
    static let report_section_title = "report_section_title".localized
    static let notifications_section_title = "notifications_section_title".localized
    static let reminder_section_title = "reminder_section_title".localized
    
    static let daily_report_button_title = "daily_report_button_title".localized
    static let daily_report_button_subtitle = "daily_report_button_subtitle".localized
    
    static let notifications_authorization_status_enabled_title = "notifications_authorization_status_enabled_title".localized
    static let notifications_authorization_status_disabled_title = "notifications_authorization_status_disabled_title".localized
    
    static let request_notifications_authorization_button_title = "request_notifications_authorization_button_title".localized
    static let open_notification_settings_button_title = "open_notification_settings_button_title".localized
    
    static let next_reminder_title = "next_reminder_title".localized
    
    static let reminder_notification_title = "reminder_notification_title".localized
    static let reminder_notification_body = "reminder_notification_body".localized
    
    fileprivate var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
}

extension Completable {
    static func create(_ context: NSManagedObjectContext, handler: @escaping () throws -> Void) -> Completable {
        .create { observer in
            context.perform {
                do {
                    try handler()
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
}

extension Single {
    static func create<T>(_ context: NSManagedObjectContext, handler: @escaping () throws -> T) -> Single<T> {
        .create { observer in
            context.perform {
                do {
                    let value = try handler()
                    observer(.success(value))
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
}
