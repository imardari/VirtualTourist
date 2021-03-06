//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Ion M on 6/1/18.
//  Copyright © 2018 Ion M. All rights reserved.
//

import Foundation

class FlickrClient {
    
    var session = URLSession.shared
    
    // MARK: Shared Instance
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    // GET Pin Locations
    func searchPhotos(_ longitude: Double, _ latitude: Double, _ pageNumber: Int = 1, completionHandlerSearchPhotos: @escaping (_ result: [String]?, _ pageNumber: Int?, _ error: NSError?)
        -> Void) {
        
        /* 1. Specify parameters, method (if has {key}), and HTTP body (if POST) */
        let methodParameters = [
            FlickrParameterKeys.Method: Methods.Search,
            FlickrParameterKeys.APIKey: Constants.APIKey,
            FlickrParameterKeys.SafeSearch: FlickrParameterValues.UseSafeSearch,
            FlickrParameterKeys.Extras: FlickrParameterValues.SquareURL,
            FlickrParameterKeys.Format: FlickrParameterValues.Json,
            FlickrParameterKeys.NoJsonCallback: FlickrParameterValues.JsonCallBackValue,
            FlickrParameterKeys.PerPage: FlickrParameterValues.PerPageValue,
            FlickrParameterKeys.Page: String(pageNumber),
            FlickrParameterKeys.Latitude: String(latitude),
            FlickrParameterKeys.Longitude: String(longitude)
        ]
        
        let request = URLRequest(url: parseURLFromParameters(methodParameters as [String : AnyObject]))
        
        /* 2. Make the request */
        let _ = performRequest(request: request as! NSMutableURLRequest) { (parsedResult, error) in
            func displayError(_ error: String) {
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerSearchPhotos(nil, nil, NSError(domain: "searchPhotos", code: 1, userInfo: userInfo))
            }
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                displayError("\(error)")
            } else {
                
                /* GUARD: Is the "photos" key in our result? */
                guard let photosDictionary = parsedResult?[FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                    displayError("Cannot find key \(FlickrResponseKeys.Photos) in \(parsedResult!)")
                    return
                }
                
                /* Guard: Is the "pages" key in our result? */
                guard let pageNumberOut = photosDictionary[FlickrResponseKeys.Pages] as? Int else {
                    displayError("Cannot find key \(FlickrResponseKeys.Pages) in \(parsedResult!)")
                    return
                }
                
                /* GUARD: Is the "photo" key in photosDictionary? */
                guard let photosArray = photosDictionary[FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                    displayError("Cannot find key \(FlickrResponseKeys.Photo) in \(parsedResult!)")
                    return
                }
                
                var urlArray = [String]()
                
                for photo in photosArray {
                    let photoDictionary = photo as [String:Any]
                    
                    /* GUARD: Does our photo have a key for 'url_q'? */
                    guard let imageUrlString = photoDictionary[FlickrResponseKeys.SquareURL] as? String else {
                        displayError("Cannot find key \(FlickrResponseKeys.SquareURL) in \(parsedResult!)")
                        return
                    }
                    urlArray.append(imageUrlString)
                }
                completionHandlerSearchPhotos(urlArray, pageNumberOut, nil)
            }
        }
    }
    
    func downloadImage(imageURL: String, completionHandler: @escaping(_ imageData: Data?, _ error: NSError?) ->  Void) -> URLSessionTask {
        let url = URL(string: imageURL)
        let request = URLRequest(url: url!)
        
        let task = session.dataTask(with: request) {data, response, downloadError in
            if downloadError != nil {
                // Do nothing
            } else {
                completionHandler(data, nil)
            }
        }
        task.resume()
        return task
    }
    
    private func performRequest(request: NSMutableURLRequest, completionHandlerRequest: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void) -> URLSessionDataTask {
            let task = session.dataTask(with: request as URLRequest) { data, response, error in
                func displayError(_ error: String) {
                    print(error)
                    let userInfo = [NSLocalizedDescriptionKey : error]
                    completionHandlerRequest(nil, NSError(domain: "performRequest", code: 1, userInfo: userInfo))
                }
                
                /* GUARD: Was there an error? */
                guard (error == nil) else {
                    displayError("There was an error with your request: \(error!)")
                    return
                }
                
                /* GUARD: Did we get a successful 2XX response? */
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                    let httpError = (response as? HTTPURLResponse)?.statusCode
                    displayError("Your request returned a status code : \(String(describing: httpError))")
                    return
                }
                
                /* GUARD: Was there any data returned? */
                guard let data = data else {
                    displayError("No data was returned by the request!")
                    return
                }
                self.convertDataWithCompletionHandler(data, completionHandlerConvertData: completionHandlerRequest)
            }
            task.resume()
            return task
    }
    
    // Convert raw JSON
    private func convertDataWithCompletionHandler(_ data: Data, completionHandlerConvertData: (_ result: AnyObject?, _ error: NSError?) -> Void) {
        var parsedResult: AnyObject! = nil
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandlerConvertData(nil, NSError(domain: "convertDataWithCompletionHandler", code: 1, userInfo: userInfo))
        }
        completionHandlerConvertData(parsedResult, nil)
    }
    
    // Create a URL from parameters
    private func parseURLFromParameters(_ parameters: [String:AnyObject]?, withPathExtension: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = Constants.ApiScheme
        components.host = Constants.ApiHost
        components.path = Constants.ApiPath + (withPathExtension ?? "")
        components.queryItems = [URLQueryItem]()
        
        if let parameters = parameters {
            for (key, value) in parameters {
                let queryItem = URLQueryItem(name: key, value: "\(value)")
                components.queryItems!.append(queryItem)
            }
        }
        return components.url!
    }
}
