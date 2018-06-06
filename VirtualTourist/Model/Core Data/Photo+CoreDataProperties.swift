//
//  Photo+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import Foundation
import CoreData

extension Photo {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }
    
    @NSManaged public var imageBinary: NSData?
    @NSManaged public var imageURL: String?
    @NSManaged public var photoToPin: Pin?
    
}
