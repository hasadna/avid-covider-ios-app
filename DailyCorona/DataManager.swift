//
//  DataManager.swift
//  DailyCorona
//
//  Created by Adar Hefer on 29/04/2020.
//  Copyright © 2020 Adar Hefer. All rights reserved.
//

import CoreData
import UserNotifications
import RxSwift
import UIKit

class DataManager {
    
    static let shared = DataManager()
    let viewContext: NSManagedObjectContext
    
    enum ViewModelType: String {
        case fillSurvey
        case notificationsAuthorizationStatus
        case reminder
        case reminderTimeSelection
        case requestNotificationsAuthorization
        case openNotificationSettings
    }
    
    func setup() {
        let group = DispatchGroup()
        group.enter()
        
        let context = container.newBackgroundContext()
        
        _ = clearAllViewModels(context: context)
            .andThen(updateSurveyCreateIfNeeded(context: context))
            .andThen(createReminderAndSettingsIfNeeded(context: context))
            .andThen(requestProvisionalPermissionIfNeeded())
            .andThen(save(context))
            .do(onDispose: {
                group.leave()
            })
            .subscribe()
        
        group.wait()
    }
    
    func setReminderEdit(enabled: Bool) -> Completable {
        let context = container.newBackgroundContext()
        
        return setReminderEdit(enabled: enabled, context: context)
            .andThen(updateReminderScheduledStatus(context: context))
            .andThen(save(context))
    }
    
    private func setReminderEdit(enabled: Bool, context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            
            if let reminder = try context.fetch(request).first {
                reminder.isBeingEdited = enabled
            }
        }
    }
    
    private func createReminderAndSettingsIfNeeded(context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let settingsRequest: NSFetchRequest<NotificationSettings> = NotificationSettings.fetchRequest()
            
            if try context.fetch(settingsRequest).first == nil {
                let _ = NotificationSettings(context: context)
            }
            
            let reminderRequest: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            
            if try context.fetch(reminderRequest).first == nil {
                let reminder = Reminder(context: context)
                reminder.notificationRequest = NotificationCenterUtils.createReminderRequest(dateComponents: .init(hour: 12))
            }
        }
    }
    
    private func requestProvisionalPermissionIfNeeded() -> Completable {
        if #available(iOS 12, *) {
            return NotificationCenterUtils.getNotificationSettings()
                .flatMapCompletable ({ settings in
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        return NotificationCenterUtils.requestAuthorization(options: [.alert, .sound, .provisional])
                            .asCompletable()
                    default:
                        return .empty()
                    }
                })
        } else {
            return .empty()
        }
    }
    
    func openSurvey() -> Completable {
        let context = container.newBackgroundContext()
        
        return getSurveyURL(context: context)
            .flatMapCompletable({ url in
                guard let url = url else {
                    return .empty()
                }
                return self.openURL(url)
                    .andThen(self.updateLastOpened(context: context))
            })
            .andThen(save(context))
    }
    
    private func getSurveyURL(context: NSManagedObjectContext) -> Single<URL?> {
        .create(context) {
            let request: NSFetchRequest<Survey> = Survey.fetchRequest()
            return try context.fetch(request).first?.url
        }
    }
    
    private func openURL(_ url: URL) -> Completable {
        .create { observer in
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url) { _ in
                        observer(.completed)
                    }
                } else {
                    observer(.completed)
                }
            }
            
            return Disposables.create()
        }
    }
    
    func updateReminder(dateComponents: DateComponents) -> Completable {
        let context = container.newBackgroundContext()
        
        return setReminderNotificationRequest(context: context, scheduled: false)
            .andThen(updateReminder(dateComponents: dateComponents, context: context))
            .andThen(updateReminderScheduledStatus(context: context))
            .andThen(save(context))
    }
        
    private func updateReminder(dateComponents: DateComponents, context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            
            if let reminder = try context.fetch(request).first {
                let notificationRequest = NotificationCenterUtils.createReminderRequest(dateComponents: dateComponents)
                reminder.notificationRequest = notificationRequest
            }
        }
    }
    
    private func updateReminderScheduledStatus(context: NSManagedObjectContext) -> Completable {
        getNotificationSettingsMO(context: context)
            .flatMapCompletable({ settingsMO in
                guard let settings = settingsMO?.settings as? UNNotificationSettings else {
                    return .empty()
                }
                
                switch settings.authorizationStatus {
                case .authorized,
                     .provisional:
                    return self.setReminderNotificationRequest(context: context, scheduled: true)
                        .andThen(self.updateReminderViewModels(settings: settings, context: context))
                default:
                    return self.setReminderNotificationRequest(context: context, scheduled: false)
                        .andThen(self.updateReminderViewModels(settings: settings, context: context))
                }
        })
    }
    
    private func getReminder(context: NSManagedObjectContext) -> Single<Reminder?> {
        .create(context) {
            let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            return try context.fetch(request).first
        }
    }
        
    private func setReminderNotificationRequest(context: NSManagedObjectContext, scheduled: Bool) -> Completable {
        getReminder(context: context)
            .flatMapCompletable({ reminder in
                if let request = reminder?.notificationRequest as? UNNotificationRequest {
                    if scheduled {
                        return NotificationCenterUtils.schedule(request: request)
                    } else {
                        return NotificationCenterUtils.unschedule(request: request)
                    }
                } else {
                    return .empty()
                }
            })
    }
    
    private func updateLastOpened(context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let request: NSFetchRequest<Survey> = Survey.fetchRequest()
            
            if let survey = try context.fetch(request).first {
                survey.lastOpened = Date()
                survey.viewModel?.touch()
            }
        }
    }
    
    func refreshNotificationSettings() -> Completable {
        let context = container.newBackgroundContext()
        
        return refreshNotificationSettings(context: context)
            .andThen(updateReminderScheduledStatus(context: context))
            .andThen(save(context))
    }
    
    private func refreshNotificationSettings(context: NSManagedObjectContext) -> Completable {
        Single.zip(NotificationCenterUtils.getNotificationSettings(),
                   getNotificationSettingsMO(context: context))
            .flatMapCompletable { settings, settingsMO in
                guard let settingsMO = settingsMO else {
                    return .empty()
                }
                return self.updateSettingsViewModels(settingsMO: settingsMO,
                                                     settings: settings,
                                                     context: context) }
    }
            
    private func clearAllViewModels(context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let request: NSFetchRequest<ViewModel> = ViewModel.fetchRequest()
            
            for vm in try context.fetch(request) {
                context.delete(vm)
            }
        }
    }
    
    private func updateSurveyCreateIfNeeded(context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let request: NSFetchRequest<Survey> = Survey.fetchRequest()
            
            let survey: Survey
            if let existing = try context.fetch(request).first {
                survey = existing
            } else {
                survey = Survey(context: context)
            }
            
            let viewModel = ViewModel(context: context)
            viewModel.section = 0
            viewModel.row = 0
            viewModel.type = ViewModelType.fillSurvey.rawValue
            survey.viewModel = viewModel
            
            if let code = Locale.current.languageCode,
                let url = self.surveyURLByLanguageCode[code] {
                survey.url = url
            } else if let url = self.surveyURLByLanguageCode["en"] {
                survey.url = url
            }
        }
    }
    
    private func getNotificationSettingsMO(context: NSManagedObjectContext) -> Single<NotificationSettings?> {
        .create(context) {
            let request: NSFetchRequest<NotificationSettings> = NotificationSettings.fetchRequest()
            return try context.fetch(request).first
        }
    }
    
    private func updateSettingsViewModels(settingsMO: NotificationSettings,
                                          settings: UNNotificationSettings,
                                          context: NSManagedObjectContext) -> Completable {
        .create(context) {
            settingsMO.viewModels?.forEach { vm in
                context.delete(vm as! NSManagedObject)
            }
            
            settingsMO.settings = settings
            
            let viewModel = ViewModel(context: context)
            viewModel.section = 1
            viewModel.row = 0
            viewModel.type = ViewModelType.notificationsAuthorizationStatus.rawValue
            settingsMO.addToViewModels(viewModel)
            
            switch settings.authorizationStatus {
            case .notDetermined,
                 .provisional:
                let viewModel = ViewModel(context: context)
                viewModel.section = 1
                viewModel.row = 1
                viewModel.type = ViewModelType.requestNotificationsAuthorization.rawValue
                settingsMO.addToViewModels(viewModel)
            case .denied:
                let viewModel = ViewModel(context: context)
                viewModel.section = 1
                viewModel.row = 1
                viewModel.type = ViewModelType.openNotificationSettings.rawValue
                settingsMO.addToViewModels(viewModel)
            default:
                break
            }
        }
    }
    
    private func updateReminderViewModels(settings: UNNotificationSettings,
                                          context: NSManagedObjectContext) -> Completable {
        .create(context) {
            let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            
            guard let reminder = try context.fetch(request).first else {
                return
            }
                                
            let vms = reminder.viewModels as! Set<ViewModel>
                                
            switch settings.authorizationStatus {
            case .authorized:
                if let vm = vms.first(where: { $0.type == ViewModelType.reminder.rawValue }) {
                    vm.touch()
                } else {
                    let viewModel = ViewModel(context: context)
                    viewModel.type = ViewModelType.reminder.rawValue
                    viewModel.section = 2
                    viewModel.row = 0
                    reminder.addToViewModels(viewModel)
                }

                if reminder.isBeingEdited {
                    if let _ = vms.first(where: { $0.type == ViewModelType.reminderTimeSelection.rawValue }) {
                        // do nothing
                    } else {
                        let viewModel = ViewModel(context: context)
                        viewModel.type = ViewModelType.reminderTimeSelection.rawValue
                        viewModel.section = 2
                        viewModel.row = 1
                        reminder.addToViewModels(viewModel)
                    }
                } else {
                    if let vm = vms.first(where: { $0.type == ViewModelType.reminderTimeSelection.rawValue }) {
                        context.delete(vm)
                    }
                }
            default:
                vms.forEach {
                    context.delete($0)
                }
            }
        }
    }
    
    private func save(_ context: NSManagedObjectContext) -> Completable {
        .create(context) {
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    private let container: NSPersistentContainer
    
    private let surveyURLByLanguageCode: [String : URL] = [
        "en" : URL(string: "https://coronaisrael.org/en/")!,
        "ar" : URL(string: "https://coronaisrael.org/ar/")!,
        "ru" : URL(string: "https://coronaisrael.org/ru/")!,
        "es" : URL(string: "https://coronaisrael.org/es/")!,
        "fr" : URL(string: "https://coronaisrael.org/fr/")!,
        "he" : URL(string: "https://coronaisrael.org")!
    ]
    
    private init() {
        container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { _, _ in }
        
        viewContext = container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
    }    
}

fileprivate extension ViewModel {
    func touch() {
        lastModified = Date()
    }
}
