//
//  DataManager.swift
//  DailyCorona
//
//  Created by Adar Hefer on 29/04/2020.
//  Copyright © 2020 Adar Hefer. All rights reserved.
//

import CoreData

class DataManager {
    
    static let shared = DataManager()
    let viewContext: NSManagedObjectContext
    
    private let surveyURLByLanguageCode: [String : URL] = [
        "en" : URL(string: "https://coronaisrael.org/en/")!,
        "he" : URL(string: "https://coronaisrael.org")!
    ]
    
    func setup() {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            do {
                try self.clearAllViewModels(context: context)
                try self.updateSurveyCreateIfNeeded(context: context)
                try self.updateNotificationAuthorizationStatusCreateIfNeeded(context: context)
                try context.save()
            } catch {
                // ignore
            }
        }
    }
    
    private func clearAllViewModels(context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<ViewModel> = ViewModel.fetchRequest()
        
        for vm in try context.fetch(request) {
            context.delete(vm)
        }
    }
    
    private func updateSurveyCreateIfNeeded(context: NSManagedObjectContext) throws {
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
        viewModel.sectionName = "SURVEY"
        survey.viewModel = viewModel
        
        if let code = Locale.current.languageCode,
            let url = self.surveyURLByLanguageCode[code] {
            survey.url = url
        }
    }
    
    private func updateNotificationAuthorizationStatusCreateIfNeeded(context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<NotificationsAuthorizationStatus> = NotificationsAuthorizationStatus.fetchRequest()
        let status: NotificationsAuthorizationStatus
        if let existing = try context.fetch(request).first {
            status = existing
        } else {
            status = .init(context: context)
        }
        
        let viewModel = ViewModel(context: context)
        viewModel.section = 1
        viewModel.row = 0
        viewModel.sectionName = "NOTIFICATIONS"
        status.viewModel = viewModel
    }
        
    func updateLastOpened() {
        let context = viewContext
        
        context.perform {
            do {
                let request: NSFetchRequest<Survey> = Survey.fetchRequest()
                
                if let survey = try context.fetch(request).first {
                    survey.lastOpened = Date()
                    survey.viewModel?.lastModified = Date()
                    try context.save()
                }
                
            } catch {
                // ignore
            }
        }
    }
    
    private let container: NSPersistentContainer
    
    
    private init() {
        container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { _, _ in }
        
        viewContext = container.viewContext
    }    
}
