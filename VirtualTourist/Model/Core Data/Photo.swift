//
//  Photo.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import Foundation
import CoreData

public class Photo: NSManagedObject {
    convenience init(urlString: String, imageData: NSData?, context: NSManagedObjectContext) {
        // Create an instance of the Image Entity
        if let ent = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: ent, insertInto: context)
            self.imageURL = urlString
            self.imageBinary = imageData
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
}

