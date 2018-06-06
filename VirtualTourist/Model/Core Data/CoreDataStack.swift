//
//  CoreDataStack.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import CoreData

struct CoreDataStack {
    
    // MARK: Properties
    let context: NSManagedObjectContext
    private let model: NSManagedObjectModel
    private let modelURL: URL
    internal let coordinator: NSPersistentStoreCoordinator
    internal let dbURL: URL
    internal let persistingContext: NSManagedObjectContext
    internal let backgroundContext: NSManagedObjectContext
    
    // MARK: Initializers
    init?(modelName: String) {
        // Verify the model is in the main bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            print("Unable to find \(modelName)in the main bundle")
            return nil
        }
        self.modelURL = modelURL
        
        // Create the model from the URL
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print("unable to create a model from \(modelURL)")
            return nil
        }
        self.model = model
        
        // Create the store coordinator
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        // Create a persistingContext (private queue)
        persistingContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // Create a context and set it to the coordinator
        persistingContext.persistentStoreCoordinator = coordinator
        // Create a persistingContext (main queue)
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        // Create a context and set it to the coordinator
        context.parent = persistingContext
        
        // Create a background context
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        // Add a SQLite store located in the documents folder
        let fm = FileManager.default

        guard let docUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to reach the documents folder")
            return nil
        }
        self.dbURL = docUrl.appendingPathComponent("model.sqlite")

        // Options for migration
        let options = [NSInferMappingModelAutomaticallyOption: true,NSMigratePersistentStoresAutomaticallyOption: true]

        do {
            try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: options as [NSObject : AnyObject]?)
        } catch {
            print("unable to add store at \(dbURL)")
        }
    }
    
    // MARK: Utils
    func addStoreCoordinator(_ storeType: String, configuration: String?, storeURL: URL, options : [NSObject:AnyObject]?) throws {
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: nil)
    }
}

// MARK: CoreDataStack (Removing Data)
internal extension CoreDataStack  {
    func dropAllData() throws {
        // Delete all the objects in the db
        try coordinator.destroyPersistentStore(at: dbURL, ofType: NSSQLiteStoreType , options: nil)
        try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: nil)
    }
}

// MARK: CoreDataStack (Batch Processing in the Background)
extension CoreDataStack {
    typealias Batch = (_ workerContext: NSManagedObjectContext) -> ()
    
    func performBackgroundBatchOperation(_ batch: @escaping Batch) {
        backgroundContext.perform() {
            batch(self.backgroundContext)
            // Save it
            do {
                try self.backgroundContext.save()
            } catch {
                fatalError("Error while saving backgroundContext: \(error)")
            }
        }
    }
}

// MARK: - CoreDataStack (Save Data)
extension CoreDataStack {
    
    func save() {
        context.performAndWait() {
            if self.context.hasChanges {
                do {
                    try self.context.save()
                } catch {
                    fatalError("Error while saving main context: \(error)")
                }
                // Save in the background
                self.persistingContext.perform() {
                    do {
                        try self.persistingContext.save()
                    } catch {
                        fatalError("Error while saving persisting context: \(error)")
                    }
                }
            }
        }
    }
    
    func autoSave(_ delayInSeconds : Int) {
        if delayInSeconds > 0 {
            do {
                try self.context.save()
            } catch {
                print("Error while autosaving")
            }
            
            let delayInNanoSeconds = UInt64(delayInSeconds) * NSEC_PER_SEC
            let time = DispatchTime.now() + Double(Int64(delayInNanoSeconds)) / Double(NSEC_PER_SEC)
            
            DispatchQueue.main.asyncAfter(deadline: time) {
                self.autoSave(delayInSeconds)
            }
        }
    }
}
