//
//  FirstViewController.swift
//  MyLocations
//
//  Created by Pedro Henrique Pereira Lima on 29/12/18.
//  Copyright © 2018 IBM. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData
import Intents
import CoreSpotlight
import MobileCoreServices

public let kNewLocationActivityType = "com.ibm.MyLocations"

class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate {
    //MARK:- Outlets
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getButton: UIButton!
    
    //MARK:- Properties
    let locationManager = CLLocationManager()
    var location: CLLocation?
    var updatingLocation = false
    var lastLocationError: Error?
    
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    
    var managedObjectContext: NSManagedObjectContext!
    
    var timer: Timer?
    
    //MARK:- Shortcut
    func newLocationShortcut() -> NSUserActivity {
        let activity = NSUserActivity(activityType: kNewLocationActivityType)
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier(kNewLocationActivityType)
        
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        activity.title = "Get my Location"
        attributes.contentDescription = "Save this Location as one of your favorite Locations!"
        //attributes.thumbnailData = thumbnail?.jpegData(compressionQuality: 1.0)
        
        activity.suggestedInvocationPhrase = "Get Location!"
        activity.contentAttributeSet = attributes

        
        return activity
    }
    
    //MARK:- View Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        updateLabels()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
    }
    
    @IBAction func getLocation() {
        getUserLocation()
    }
    
    //MARK:- Methods
    func getUserLocation() {
        let authStatus = CLLocationManager.authorizationStatus()
        
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            placemark = nil
            lastGeocodingError = nil
            startLocationManager()
        }
        
        updateLabels()
        
        let activity = newLocationShortcut()
        self.userActivity = activity
        
        activity.becomeCurrent()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as NSError).code == CLError.locationUnknown.rawValue { return }
        
        lastLocationError = error
        stopLocationManager()
        updateLabels()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!

        if newLocation.timestamp.timeIntervalSinceNow < -5 { return }

        if newLocation.horizontalAccuracy < 0 { return }
        
        var distance = CLLocationDistance(Double.greatestFiniteMagnitude)
        if let location = location { distance = newLocation.distance(from: location)}

        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            lastLocationError = nil
            location = newLocation
            
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {
                stopLocationManager()
                if distance > 0 { performingReverseGeocoding = false }
            }
            
            updateLabels()
            
            if !performingReverseGeocoding {
                performingReverseGeocoding = true
                geocoder.reverseGeocodeLocation(newLocation, completionHandler: { placemarks, error in
                    self.lastGeocodingError = error
                    if error == nil, let p = placemarks, !p.isEmpty {
                        self.placemark = p.last!
                    } else {
                        self.placemark = nil
                    }
                    self.performingReverseGeocoding = false
                    self.updateLabels()
                })
            }
        } else if distance < 1 {
            let timeInterval = newLocation.timestamp.timeIntervalSince(location!.timestamp)
            if timeInterval > 10 {
                stopLocationManager()
                updateLabels()
            }
        }
    }
    
    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            updatingLocation = true
            
            timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(didTimeOut), userInfo: nil, repeats: false)
        }
    }
    
    func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
            if let timer = timer { timer.invalidate() }
        }
    }
    
    func updateLabels() {
        if let location = location {
            latitudeLabel?.text = String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel?.text = String(format: "%.8f", location.coordinate.longitude)
            tagButton?.isHidden = false
            messageLabel?.text = ""
            
            if let placemark = placemark {
                addressLabel?.text = string(from: placemark)
            } else if performingReverseGeocoding {
                addressLabel?.text = "Searching for Address..."
            } else if lastGeocodingError != nil {
                addressLabel?.text = "Error Finding Address"
            } else {
                addressLabel?.text = "No Address Found"
            }
            
        } else {
            latitudeLabel?.text = ""
            longitudeLabel?.text = ""
            addressLabel?.text = ""
            tagButton?.isHidden = true
            
            let statusMessage: String
            
            if let error = lastLocationError as NSError? {
                if error.domain == kCLErrorDomain && error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = "Tap 'Get My Location' to Start"
            }
            messageLabel?.text = statusMessage
        }
        configureGetButton()
    }
    
    func configureGetButton() {
        if updatingLocation {
            getButton?.setTitle("Stop", for: .normal)
        } else {
            getButton?.setTitle("Get My Location", for: .normal)
        }
    }
    
    func string(from placemark: CLPlacemark) -> String {
        var line1 = ""

        if let s = placemark.subThoroughfare { line1 += s + " " }
        if let s = placemark.thoroughfare { line1 += s }

        var line2 = ""
        
        if let s = placemark.locality { line2 += s + " " }
        if let s = placemark.administrativeArea { line2 += s + " " }
        if let s = placemark.postalCode { line2 += s }
        
        return line1 + "\n" + line2
    }
    
    //MARK:- Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TagLocation" {
            let controller = segue.destination as! LocationDetailsViewController
            controller.coordinate = location!.coordinate
            controller.placemark = placemark
            controller.managedObjectContext = managedObjectContext
        }
    }
    
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled", message: "Please enable location services for this app in Settings.", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        present(alert, animated: true, completion: nil)
        alert.addAction(okAction)
    }
    
    //MARK:- Help Method
    @objc func didTimeOut() {
        if location == nil {
            stopLocationManager()
            lastLocationError = NSError(domain: "MyLocationsErrorDomain", code: 1, userInfo: nil)
            updateLabels()
        }
    }
}
