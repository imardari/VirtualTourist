//
//  PhotoViewController.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//


import UIKit
import MapKit
import CoreData

class PhotoViewController: UIViewController {
    
    @IBOutlet weak var buttonPictureAction: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    // Selected location from previous navigation controller
    var selectedLocation: Pin!
    
    // Core Data Stack
    var coreDataStack: CoreDataStack?
    
    // Insert, Delete, and Update index for the fetched results controller
    var insertIndexes = [IndexPath]()
    var deleteIndexes = [IndexPath]()
    var updateIndexes = [IndexPath]()
    
    // Selected Index is used to delete the pictures
    var selectedIndexes = [IndexPath]()
    
    // Set the totalPageNumber to 1. A random number will be generated after the first request
    var totalPageNumber : Int = 1
    var currentPageNumber = 1
    var downloadCounter = 0
    
    // String Constants for button name
    let removeImage = "Remove selected pictures"
    let newCollection = "New Collection"
    
    lazy var fetchedResultsController: NSFetchedResultsController<Photo> = {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "imageURL", ascending: true)]
        request.predicate = NSPredicate(format: "photoToPin == %@", self.selectedLocation)
        
        let moc = coreDataStack?.context
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: request as! NSFetchRequest<Photo>, managedObjectContext: moc!, sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultsController
    }()
    
    func performFetch() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Core data stack
        let delegate = UIApplication.shared.delegate as! AppDelegate
        coreDataStack = delegate.stack
        
        // Delegates
        mapView.delegate = self
        collectionView.delegate = self
        fetchedResultsController.delegate = self
        
        // Init layout
        initLayout(size: view.frame.size)
        
        performFetch()
        initMap()
        initPhotos()
        
        // Disable refresh button
        self.buttonPictureAction.isEnabled = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        initLayout(size: size)
    }
    
    // Mark : Init layout
    func initLayout(size: CGSize) {
        let space: CGFloat = 3.0
        let dimension: CGFloat
        
        dimension = (size.width - (2 * space)) / 3.0
        
        flowLayout?.minimumInteritemSpacing = space
        flowLayout?.minimumLineSpacing = space
        flowLayout?.itemSize = CGSize(width: dimension, height: dimension)
    }
    
    // Mark: Init map
    private func initMap() {
        
        let annotation = MKPointAnnotation()
        annotation.coordinate.latitude = selectedLocation.latitude
        annotation.coordinate.longitude = selectedLocation.longitude
        
        let centerCoordinate = CLLocationCoordinate2D(latitude: selectedLocation.latitude, longitude: selectedLocation.longitude)
        let spanCoordinate = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        let region = MKCoordinateRegion(center: centerCoordinate, span: spanCoordinate)
        
        DispatchQueue.main.async {
            self.mapView.setRegion(region, animated: true)
            self.mapView.addAnnotation(annotation)
        }
    }
    
    // Mark: Init photos
    private func initPhotos() {
        if (fetchedResultsController.fetchedObjects?.count == 0) {
            getPhotoFromFlickr(currentPageNumber)
        }
    }
    
    private func getPhotoFromFlickr(_ pageNumber: Int) {
        FlickrClient.sharedInstance().searchPhotos(selectedLocation.longitude, selectedLocation.latitude, pageNumber, completionHandlerSearchPhotos: { (result, pageNumberResult, error ) in
            if (error == nil) {
                // Hide the collection view if there was no result. Update the label
                if (result?.count == 0) {
                    DispatchQueue.main.async {
                        self.collectionView.isHidden = true
                    }
                }
                
                self.coreDataStack?.context.perform {
                    for urlString in result! {
                        let image = Photo(urlString: urlString, imageData: nil, context: (self.coreDataStack?.context)!)
                        self.selectedLocation.addToPinToPhoto(image)
                    }
                }
                self.totalPageNumber = pageNumberResult!
            }
            else {
                self.alertError("Fail to get images from Flickr")
            }
        })
    }
    
    private func downloadImages() {
        coreDataStack?.performBackgroundBatchOperation { (workerContext) in
            for image in self.fetchedResultsController.fetchedObjects! {
                if image.imageBinary == nil {
                    _ = FlickrClient.sharedInstance().downloadImage(imageURL: image.imageURL!, completionHandler: { (imageData, error) in
                        
                        if (error == nil) {
                            image.imageBinary = imageData as NSData?
                        }
                        else {
                            print("Download error")
                        }
                    })
                }
            }
        }
    }
    
    // Delete selected image
    private func deleteSelectedImage() {
        for index in selectedIndexes {
            coreDataStack?.context.delete(fetchedResultsController.object(at: index))
        }
        // Reset indexes
        selectedIndexes.removeAll()
        // Save
        coreDataStack?.save()
        // Update UI
        buttonPictureAction.setTitle(newCollection, for: .normal)
    }
    
    // Delete all of the existing images
    private func clearImages() {
        for object in fetchedResultsController.fetchedObjects! {
            coreDataStack?.context.delete(object)
        }
        coreDataStack?.save()
    }
    
    private func alertError(_ alertMessage: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Alert", message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func loadNewCollection(_ sender: Any) {
        if (buttonPictureAction.titleLabel?.text == newCollection) {
            // Disable the button
            buttonPictureAction.isEnabled = false
            // Delete all images
            clearImages()
            // Get new images
            if (currentPageNumber < totalPageNumber) {
                currentPageNumber = currentPageNumber + 1
            }
            else {
                currentPageNumber = totalPageNumber
            }
            self.collectionView.isHidden = false
            
            getPhotoFromFlickr(currentPageNumber)
            downloadImages()
        } else {
            deleteSelectedImage()
        }
    }
}

extension PhotoViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionViewCell", for: indexPath as IndexPath) as! PictureCollectionViewCell
        
        DispatchQueue.main.async {
            cell.imageView.image = nil
            cell.activityIndicator.startAnimating()
        }
        
        let image = fetchedResultsController.object(at: indexPath)
        
        // Update the UI after image download
        if let imageData = image.imageBinary {
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: imageData as Data)
                cell.activityIndicator.stopAnimating()
                
                if (self.downloadCounter > 0) {
                    self.downloadCounter = self.downloadCounter - 1
                }
                if self.downloadCounter == 0 {
                    self.buttonPictureAction.isEnabled = true
                }
            }
        }
        else {
            // Download image
            self.downloadCounter = self.downloadCounter + 1
            let task = FlickrClient.sharedInstance().downloadImage(imageURL: image.imageURL!, completionHandler: { (imageData, error) in
                if (error == nil) {
                    DispatchQueue.main.async {
                        cell.activityIndicator.stopAnimating()
                        if (self.downloadCounter > 0) {
                            self.buttonPictureAction.isEnabled = false
                        }
                    }
                    self.coreDataStack?.context.perform {
                        image.imageBinary = imageData as NSData?
                    }
                } else {
                    print("There was an error downloading the image: \(error!)")
                }
            })
            cell.cancellTask = task
        }
        return cell
    }
}

extension PhotoViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Reset indexes
        insertIndexes.removeAll()
        deleteIndexes.removeAll()
        updateIndexes.removeAll()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        // Assign all indexes so that we can update the cell accordingly
        switch (type) {
        case .insert:
            insertIndexes.append(newIndexPath!)
        case .delete:
            deleteIndexes.append(indexPath!)
        case .update:
            updateIndexes.append(indexPath!)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates( {
            self.collectionView.insertItems(at: insertIndexes)
            self.collectionView.deleteItems(at: deleteIndexes)
            self.collectionView.reloadItems(at: updateIndexes)
        }, completion: nil)
    }
}

extension PhotoViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Get the cell user selected
        let cell = collectionView.cellForItem(at: indexPath as IndexPath)
        if (!selectedIndexes.contains(indexPath)) {
            // Add it to the selected index
            selectedIndexes.append(indexPath)
            cell?.alpha = 0.5
        } else {
            // Remove index from selected indexes
            let index = selectedIndexes.index(of: indexPath)
            selectedIndexes.remove(at: index!)
            cell?.alpha = 1
        }
        // Change barButton title whenever the user selects photo(s)
        if (selectedIndexes.count == 0) {
            buttonPictureAction.setTitle(newCollection, for: .normal)
        } else {
            buttonPictureAction.setTitle(removeImage, for: .normal)
        }
    }
}

extension PhotoViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
}
