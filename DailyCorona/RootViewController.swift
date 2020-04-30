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

class RootViewController: UITableViewController {

    private enum Section: String, CaseIterable {
        case survey = "SURVEY"
        case notifications = "NOTIFICATIONS"
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
                
        title = "Corona Survey"
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
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
        if let _ = vm.survey {
            reuseIdentifier = "surveyReuseIdentifier"
        } else if let _ = vm.authorizationStatus {
            reuseIdentifier = "notificationsAuthorizationStatusReuseIdentifier"
        } else {
            fatalError()
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        configure(cell, at: indexPath)
        
        return cell
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let vm = frc.object(at: indexPath)
        
        if let survey = vm.survey {
            if let lastOpened = survey.lastOpened {
                cell.detailTextLabel?.text = "Last opened: \(dateFormatter.string(from: lastOpened))"
            } else {
                cell.detailTextLabel?.text = nil
            }
            
            cell.textLabel?.text = "Fill Survey"
            cell.accessoryType = .disclosureIndicator
        }
        
        if let authorizationStatus = vm.authorizationStatus,
            let status = UNAuthorizationStatus(rawValue: Int(authorizationStatus.status)) {
            
            switch status {
            case .authorized:
                cell.textLabel?.text = "Notifications Enabled"
            case .provisional:
                cell.textLabel?.text = "Silent Notifications Enabled"
            default:
                cell.textLabel?.text = "Notifications Disabled"
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vm = frc.object(at: indexPath)
        
        if let survey = vm.survey {
            if let url = survey.url {
                let vc = SFSafariViewController(url: url)
                
                DataManager.shared.updateLastOpened()
                present(vc, animated: true, completion: nil)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let vm = frc.object(at: indexPath)
        
        if let _ = vm.survey {
            return true
        } else {
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

