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
        case requestNotificationsAuthorization
        case openNotificationSettings
    }
    
    func setup() -> Completable {
        let context = container.newBackgroundContext()
        
        return clearAllViewModels(context: context)
            .andThen(updateSurveyCreateIfNeeded(context: context))
            .andThen(requestProvisionalPermissionIfNeeded())
            .andThen(save(context))
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
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<Survey> = Survey.fetchRequest()
                    
                    observer(.success(try context.fetch(request).first?.url))
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
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
    
    private func scheduleDefaultReminderIfNeeded(context: NSManagedObjectContext) -> Completable {
        getNotificationSettingsMOCreateIfNeeded(context: context)
            .map { $0.settings as! UNNotificationSettings }
            .flatMapCompletable({ settings in
                switch settings.authorizationStatus {
                case .authorized,
                     .provisional:
                    return self.scheduleReminder(dateComponents: .init(hour: 12),
                                                 overrideExisting: false,
                                                 context: context)
                        .andThen(self.updateReminderViewModel(settings: settings,
                                                              context: context))
                default:
                    return .empty()
                }
            })
    }
    
    private func scheduleReminder(dateComponents: DateComponents, overrideExisting: Bool, context: NSManagedObjectContext) -> Completable {
        if overrideExisting {
            return scheduleReminder(dateComponents: dateComponents, context: context)
        } else {
            return existingNotificationRequest(context: context)
                .flatMapCompletable({ request in
                    if let _ = request {
                        return .empty()
                    } else {
                        return self.scheduleReminder(dateComponents: dateComponents, context: context)
                    }
                })
        }
    }
    
    private func scheduleReminder(dateComponents: DateComponents, context: NSManagedObjectContext) -> Completable {
        let request = NotificationCenterUtils.createReminderRequest(dateComponents: dateComponents)
        return NotificationCenterUtils.schedule(request: request)
            .andThen(createReminderIfNeeded(notificationRequest: request, context: context))
    }
    
    private func existingNotificationRequest(context: NSManagedObjectContext) -> Single<UNNotificationRequest?> {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
                    
                    if let reminder = try context.fetch(request).first {
                        observer(.success(reminder.notificationRequest as? UNNotificationRequest))
                    } else {
                        observer(.success(nil))
                    }
                    
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    private func createReminderIfNeeded(notificationRequest: UNNotificationRequest, context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
                    
                    let reminder: Reminder
                    if let existing = try context.fetch(request).first {
                        reminder = existing
                    } else {
                        reminder = Reminder(context: context)
                        
                    }
                    reminder.notificationRequest = notificationRequest
                    
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    private func unscheduleReminder(context: NSManagedObjectContext) -> Completable {
        existingNotificationRequest(context: context)
            .flatMapCompletable({
                if let request = $0 {
                    return NotificationCenterUtils.unschedule(request: request)
                } else {
                    return .empty()
                }
            })
    }
    
    private func updateLastOpened(context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<Survey> = Survey.fetchRequest()
                    
                    if let survey = try context.fetch(request).first {
                        survey.lastOpened = Date()
                        survey.viewModel?.touch()
                    }
                    
                    observer(.completed)
                    
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    func refreshNotificationSettings() -> Completable {
        let context = container.newBackgroundContext()
        
        return refreshNotificationSettings(context: context)
            .andThen(scheduleDefaultReminderIfNeeded(context: context))
            .andThen(updateReminder(context: context))
            .andThen(save(context))
    }
    
    private func refreshNotificationSettings(context: NSManagedObjectContext) -> Completable {
        Single.zip(NotificationCenterUtils.getNotificationSettings(),
                   getNotificationSettingsMOCreateIfNeeded(context: context))
            .flatMapCompletable { settings, settingsMO in
                self.updateSettingsViewModels(settingsMO: settingsMO,
                                              settings: settings,
                                              context: context) }
    }
    
    func updateReminder() -> Completable {
        let context = container.newBackgroundContext()
        
        return updateReminder(context: context)
            .andThen(save(context))
    }
    
    private func updateReminder(context: NSManagedObjectContext) -> Completable {
        Single.zip(getNotificationSettingsMOCreateIfNeeded(context: context),
                   existingNotificationRequest(context: context))
            .flatMapCompletable({ settingsMO, request in
                guard let request = request else {
                    return .empty()
                }
                
                let settings = settingsMO.settings as! UNNotificationSettings
                
                switch settings.authorizationStatus {
                case .authorized,
                     .provisional:
                    return NotificationCenterUtils.schedule(request: request)
                        .andThen(self.updateReminderViewModel(settings: settings,
                                                              context: context))
                default:
                    return NotificationCenterUtils.unschedule(request: request)
                        .andThen(self.updateReminderViewModel(settings: settings,
                                                              context: context))
                }
            })
    }
    
    private func clearAllViewModels(context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<ViewModel> = ViewModel.fetchRequest()
                    
                    for vm in try context.fetch(request) {
                        context.delete(vm)
                    }
                    
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    private func updateSurveyCreateIfNeeded(context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                do {
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
                    }
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    private func getNotificationSettingsMOCreateIfNeeded(context: NSManagedObjectContext) -> Single<NotificationSettings> {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<NotificationSettings> = NotificationSettings.fetchRequest()
                    let settingsMO: NotificationSettings
                    if let existing = try context.fetch(request).first {
                        settingsMO = existing
                    } else {
                        settingsMO = .init(context: context)
                    }
                    observer(.success(settingsMO))
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    private func updateSettingsViewModels(settingsMO: NotificationSettings,
                                          settings: UNNotificationSettings,
                                          context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
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
                
                observer(.completed)
            }
            
            return Disposables.create()
        }
    }
    
    private func updateReminderViewModel(settings: UNNotificationSettings,
                                         context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
                    
                    guard let reminder = try context.fetch(request).first else {
                        observer(.completed)
                        return
                    }
                    
                    reminder.viewModels?.forEach { vm in
                        context.delete(vm as! NSManagedObject)
                    }
                    
                    switch settings.authorizationStatus {
                    case .authorized,
                         .provisional:
                        let viewModel = ViewModel(context: context)
                        viewModel.type = ViewModelType.reminder.rawValue
                        viewModel.section = 2
                        viewModel.row = 0
                        reminder.addToViewModels(viewModel)
                    default:
                        break
                    }
                    
                    observer(.completed)
                    
                } catch {
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    private func save(_ context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                guard context.hasChanges else {
                    observer(.completed)
                    return
                }
                
                do {
                    try context.save()
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            
            return Disposables.create()
        }
    }
    
    private let container: NSPersistentContainer
    
    private let surveyURLByLanguageCode: [String : URL] = [
        "en" : URL(string: "https://coronaisrael.org/en/")!,
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
