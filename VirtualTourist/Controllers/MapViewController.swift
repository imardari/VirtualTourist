//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var labelDelete: UILabel!
    @IBOutlet weak var buttonEdit: UIBarButtonItem!
    
    var coreDataStack: CoreDataStack?
    var onEdit = false
    var locations = [Pin]()
    
    let stringLatitude = "Latitude"
    let stringLongitude = "Longitude"
    let stringLatitudeDelta = "LatitudeDelta"
    let stringLongitudeDelta = "LongitudeDelta"
    let stringFirstLaunch = "FirstLaunch"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize core data stack
        let delegate = UIApplication.shared.delegate as! AppDelegate
        coreDataStack = delegate.stack
        mapView.delegate = self
        
        initMapSetting()
        loadLocations()
    }
    
    private func initMapSetting() {
        let defaults = UserDefaults.standard
        if UserDefaults.standard.bool(forKey: stringFirstLaunch) {
            let centerLatitude  = defaults.double(forKey: stringLatitude)
            let centerLongitude = defaults.double(forKey: stringLongitude)
            let latitudeDelta   = defaults.double(forKey: stringLatitudeDelta)
            let longitudeDelta  = defaults.double(forKey: stringLongitudeDelta)
            
            let centerCoordinate = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
            let spanCoordinate = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            let region = MKCoordinateRegion(center: centerCoordinate, span: spanCoordinate)
            
            DispatchQueue.main.async {
                self.mapView.setRegion(region, animated: true)
            }
        } else {
            defaults.set(true, forKey: stringFirstLaunch)
        }
    }
    
    // Get locations from CoreData
    private func loadLocations() {
        let request: NSFetchRequest<Pin> = Pin.fetchRequest()
        if let result = try? coreDataStack?.context.fetch(request) {
            var annotationsArray = [MKPointAnnotation]()
            for location in result! {
                let annotation = MKPointAnnotation()
                annotation.coordinate.latitude = location.latitude
                annotation.coordinate.longitude = location.longitude
                annotationsArray.append(annotation)
                locations.append(location)
            }
            DispatchQueue.main.async {
                self.mapView.addAnnotations(annotationsArray)
            }
        }
    }
    
    // Get location from CoreData
    private func getLocation(longitude: Double, latitude: Double) -> Pin? {
        var location: Pin?
        let request: NSFetchRequest<Pin> = Pin.fetchRequest()
        
        if let result = try? coreDataStack?.context.fetch(request) {
            for locationInResult in result! {
                if (locationInResult.latitude == latitude && locationInResult.longitude == longitude) {
                    location = locationInResult
                    break
                }
            }
        }
        return location
    }
    
    private func getPhotoFromFlickr(_ pageNumber: Int, _ location: Pin) {
        FlickrClient.sharedInstance().searchPhotos(location.longitude, location.latitude, pageNumber, completionHandlerSearchPhotos: { (result, pageNumberResult, error ) in
            if (error == nil) {
                for urlString in result! {
                    self.coreDataStack?.context.perform {
                        let image = Photo(urlString: urlString, imageData: nil, context: (self.coreDataStack?.context)!)
                        location.totalFlickrPages = Int32(pageNumberResult!)
                        location.addToPinToPhoto(image)
                    }
                }
            }
            else {
                print("Failed to get photo from flickr")
            }
        })
    }
    
    // MARK : Actions
    @IBAction func onEditAction(_ sender: Any) {
        // Shift map up
        if (buttonEdit.title == "Edit") {
            labelDelete.isHidden = false
            buttonEdit.title = "Done"
            onEdit = true
        }
        else {
            labelDelete.isHidden = true
            buttonEdit.title = "Edit"
            onEdit = false
        }
    }
    
    @IBAction func onLongPressAction(_ sender: Any) {
        let lpg = sender as? UILongPressGestureRecognizer
        let pressPoint = lpg?.location(in: mapView)
        let pressCoordinate = mapView.convert(pressPoint!, toCoordinateFrom: mapView)

        let annotation = MKPointAnnotation()
        annotation.coordinate = pressCoordinate

        let annotations = mapView.annotations

        var isFound = false
        for annotationEntry in annotations {
            if (annotationEntry.coordinate.latitude == pressCoordinate.latitude && annotationEntry.coordinate.longitude == pressCoordinate.longitude) {
                isFound = true
                break
            }
        }

        if !isFound {
            // Add map annotation
            self.mapView.addAnnotation(annotation)
            // Persist the location to the core data
            let location = Pin(longitude: annotation.coordinate.longitude, latitude: annotation.coordinate.latitude, context: (coreDataStack?.context)!)
            locations.append(location)
            // Fetch flickr
            getPhotoFromFlickr(1, location)
        }
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    // Save the region every time we change the map
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(self.mapView.region.center.latitude, forKey: stringLatitude)
        defaults.set(self.mapView.region.center.longitude, forKey: stringLongitude)
        defaults.set(self.mapView.region.span.latitudeDelta, forKey: stringLatitudeDelta)
        defaults.set(self.mapView.region.span.longitudeDelta, forKey: stringLongitudeDelta)
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView){
        let coordinate = view.annotation?.coordinate
        if (onEdit) {
            // Delete pin(s)
            for location in locations {
                if location.latitude == (coordinate!.latitude) && location.longitude == (coordinate!.longitude) {
                    let annotationToRemove = view.annotation
                    self.mapView.removeAnnotation(annotationToRemove!)
                    coreDataStack?.context.delete(location)
                    coreDataStack?.save()
                    break
                }
            }
        } else {
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "photosVC") as! PhotoViewController
            
            // Grab the pin object from Core Data
            let location = self.getLocation(longitude: coordinate!.longitude, latitude: coordinate!.latitude)
            
            vc.selectedLocation = location
            vc.totalPageNumber = location?.value(forKey: "totalFlickrPages") as! Int
            
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}
