//
//  Pin.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import Foundation
import CoreData

public class Pin: NSManagedObject {

    convenience init(longitude: Double, latitude: Double, context: NSManagedObjectContext) {
        // Create an instance of the Pin Entity
        if let ent = NSEntityDescription.entity(forEntityName: "Pin", in: context) {
            self.init(entity: ent, insertInto: context)
            self.longitude = longitude
            self.latitude = latitude
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
}

