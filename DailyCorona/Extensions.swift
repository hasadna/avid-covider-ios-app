//
//  Extensions.swift
//  CourseQuery
//
//  Created by Adar Hefer on 28/08/2019.
//  Copyright © 2019 Adar Hefer. All rights reserved.
//

import UIKit

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
