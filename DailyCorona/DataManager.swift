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

class DataManager {
    
    static let shared = DataManager()
    let viewContext: NSManagedObjectContext
    
    enum ViewModelType: String {
        case fillSurvey
        case notificationsAuthorizationStatus
        case requestNotificationsAuthorization
        case openNotificationSettings
    }
    
    func setup() -> Completable {
        let context = container.newBackgroundContext()
        
        return clearAllViewModels(context: context)
            .andThen(updateSurveyCreateIfNeeded(context: context))
            .andThen(requestProvisionalPermissionIfNeeded())
            .andThen(refreshNotificationSettings(context: context))
            .andThen(save(context))
    }
        
    private func requestProvisionalPermissionIfNeeded() -> Completable {
        if #available(iOS 13, *) {
            return NotificationCenterUtils.getNotificationSettings()
                .flatMapCompletable ({ settings in
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        return NotificationCenterUtils.requestAuthorization(options: [.badge, .alert, .provisional])
                            .asCompletable()
                    default:
                        return .empty()
                    }
                })
        } else {
            return .empty()
        }
    }
    
    func updateLastOpened() -> Completable {
        let context = container.newBackgroundContext()
        
        return updateLastOpened(context: context)
            .andThen(save(context))
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
            .andThen(save(context))
    }
    
    private func refreshNotificationSettings(context: NSManagedObjectContext) -> Completable {
        Single.zip(NotificationCenterUtils.getNotificationSettings(),
                   getNotificationSettingsMOCreateIfNeeded(context: context))
            .flatMapCompletable { settings, settingsMO in
                self.updateViewModelsCreateIfNeeded(settingsMO: settingsMO,
                                                    settings: settings,
                                                    context: context) }
    }
    
    private func clearAllViewModels(context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                do {
                    let request: NSFetchRequest<ViewModel> = ViewModel.fetchRequest()
                    
                    for vm in try context.fetch(request) {
                        context.delete(vm)
                    }
                    
                    try context.save()
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
        
    private func updateViewModelsCreateIfNeeded(settingsMO: NotificationSettings,
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
    
    private func save(_ context: NSManagedObjectContext) -> Completable {
        .create { observer in
            context.perform {
                if context.hasChanges {
                    do {
                        try context.save()
                        observer(.completed)
                    } catch {
                        observer(.error(error))
                    }
                } else {
                    observer(.completed)
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
