//
//  RootViewController.swift
//  DailyCorona
//
//  Created by Adar Hefer on 29/04/2020.
//  Copyright © 2020 Adar Hefer. All rights reserved.
//

import UIKit
import CoreData
import SafariServices
import RxSwift

class RootViewController: UITableViewController {

    private enum Section: String, CaseIterable {
        case survey = "REPORT"
        case notifications = "NOTIFICATIONS"
        case reminder = "DAILY REMINDER"
    }
    
    private var frc: NSFetchedResultsController<ViewModel>!
    
    override func viewDidLoad() {
        let request: NSFetchRequest<ViewModel> = ViewModel.fetchRequest()
        request.sortDescriptors = [.init(keyPath: \ViewModel.section, ascending: true),
                                   .init(keyPath: \ViewModel.row, ascending: true)]
        frc = .init(fetchRequest: request,
                    managedObjectContext: DataManager.shared.viewContext,
                    sectionNameKeyPath: #keyPath(ViewModel.section),
                    cacheName: nil)
        frc.delegate = self
        
        try? frc.performFetch()
                
        title = "Daily Health Report"
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

}

extension RootViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        frc.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        frc.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier: String
        let vm = frc.object(at: indexPath)
        
        let viewModelType = DataManager.ViewModelType(rawValue: vm.type!)!
        
        switch viewModelType {
        case .fillSurvey:
            reuseIdentifier = "surveyReuseIdentifier"
        case .notificationsAuthorizationStatus:
            reuseIdentifier = "notificationsAuthorizationStatusReuseIdentifier"
        case .requestNotificationsAuthorization:
            reuseIdentifier = "buttonReuseIdentifier"
        case .openNotificationSettings:
            reuseIdentifier = "buttonReuseIdentifier"
        case .reminder:
            reuseIdentifier = "notificationsAuthorizationStatusReuseIdentifier"
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        configure(cell, at: indexPath)
        
        return cell
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let vm = frc.object(at: indexPath)
        
        let viewModelType = DataManager.ViewModelType(rawValue: vm.type!)!
        
        cell.accessoryView = nil
        
        switch viewModelType {
        case .fillSurvey:
           let survey = vm.survey!
            
            if let lastOpened = survey.lastOpened {
                cell.detailTextLabel?.text = "Last opened on \(dateFormatter.string(from: lastOpened))"
            } else {
                cell.detailTextLabel?.text = nil
            }
            
            cell.textLabel?.text = "COVID-19 Daily Report"
            cell.accessoryType = .disclosureIndicator
        case .notificationsAuthorizationStatus:
            let settings = vm.notificationSettings!.settings as! UNNotificationSettings
            
            switch settings.authorizationStatus {
            case .authorized:
                cell.textLabel?.text = "Enabled"
            default:
                cell.textLabel?.text = "Disabled"
            }
        case .requestNotificationsAuthorization:
            cell.textLabel?.text = "Enable Notifications"
            cell.textLabel?.textColor = cell.textLabel?.tintColor
        case .openNotificationSettings:
            cell.textLabel?.text = "Open Notification Settings"
            cell.textLabel?.textColor = cell.textLabel?.tintColor
        case .reminder:
            let request = vm.reminder!.notificationRequest as! UNNotificationRequest
            let trigger = request.trigger as! UNCalendarNotificationTrigger
            let date = trigger.nextTriggerDate()!
            
            cell.textLabel?.text = "Next Reminder"
            
            let label = UILabel()
            label.text = dateFormatter.string(from: date)
            label.sizeToFit()
            
            cell.accessoryView = label
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vm = frc.object(at: indexPath)
        
        let viewModelType = DataManager.ViewModelType(rawValue: vm.type!)!
        
        switch viewModelType {
        case .fillSurvey:
            let url = vm.survey!.url!
            
            let vc = SFSafariViewController(url: url)
            
            _ = DataManager.shared.updateLastOpened().subscribe()
            
            present(vc, animated: true, completion: nil)
        case .requestNotificationsAuthorization:
            _ = NotificationCenterUtils.requestAuthorization(options: [.alert, .sound])
                .asCompletable()
                .andThen(DataManager.shared.refreshNotificationSettings())
                .observeOn(MainScheduler.instance)
                .subscribe(onCompleted: {
                    tableView.deselectRow(at: indexPath, animated: true)
                })
                
        case .openNotificationSettings:
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl) { success in
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        case .notificationsAuthorizationStatus,
             .reminder:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let vm = frc.object(at: indexPath)
        
        let viewModelType = DataManager.ViewModelType(rawValue: vm.type!)!
        
        switch viewModelType {
        case .fillSurvey,
             .requestNotificationsAuthorization,
             .openNotificationSettings:
            return true
        case .notificationsAuthorizationStatus,
             .reminder:
            return false
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section.allCases[section].rawValue
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension RootViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .move, .update:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                tableView.moveRow(at: indexPath, to: newIndexPath)
                
                if let cell = tableView.cellForRow(at: indexPath) {
                    configure(cell, at: newIndexPath)
                }
            }
        @unknown default:
            fatalError()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections([sectionIndex], with: .fade)
        case .delete:
            tableView.deleteSections([sectionIndex], with: .fade)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

