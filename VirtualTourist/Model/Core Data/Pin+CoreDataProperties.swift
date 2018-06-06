//
//  Pin+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import Foundation
import CoreData

extension Pin {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pin> {
        return NSFetchRequest<Pin>(entityName: "Pin")
    }
    
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var totalFlickrPages: Int32
    @NSManaged public var pinToPhoto: NSSet?
}

// MARK: Generated accessors for pinToPhoto
extension Pin {
    
    @objc(addPinToPhotoObject:)
    @NSManaged public func addToPinToPhoto(_ value: Photo)
    
    @objc(removePinToPhotoObject:)
    @NSManaged public func removeFromPinToPhoto(_ value: Photo)
    
    @objc(addPinToPhoto:)
    @NSManaged public func addToPinToPhoto(_ values: NSSet)
    
    @objc(removePinToPhoto:)
    @NSManaged public func removeFromPinToPhoto(_ values: NSSet)
}

