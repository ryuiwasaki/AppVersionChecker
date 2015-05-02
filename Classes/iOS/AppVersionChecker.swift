//
//  AppVersionChecker.swift
//
//  Created by Ryu Iwasaki on 2015/05/01.
//  Copyright 2015 Ryu Iwasaki. All rights reserved.

// Needs Swift 1.2

import Foundation
import Alamofire

public class AppVersionChecker {

    private enum iTunesEndPoint : String {
        
        case AppID = "https://itunes.apple.com/%@/lookup?id=%@"
        case BundleID = "https://itunes.apple.com/%@/lookup?bundleId=%@"
        
        func URL(locale:NSLocale = NSLocale.currentLocale(),id:String) -> NSURL {
            
            if let country = locale.objectForKey(NSLocaleCountryCode) as? String {
                let str = String(format: self.rawValue, country,id)
                
                if let url =  NSURL(string: str) {
                    return url
                }
            }
            
            let str = String(format: self.rawValue, "US",id)
            
            return NSURL(string: str)!
        }
    }
    
    private static let kVersion = "version"
    private static let kOptional = "optional"
    private static let kAppStoreResultsKey = "results"
    private static let kAppStoreURLKey = "trackViewUrl"
    private static let kAppStoreVersionKey = "version"
    private static let kAppStoreReleaseNotesKey = "releaseNotes"
    
    public static let sharedInstance = AppVersionChecker()
    
    public var jsonURL = ""
    public var alertTitle = ""
    public var alertBody = ""
    public var appID : String?
    
    private var currentVersion : String {
        
        return NSBundle.currentVersion()
    }
    
    private var endpoint : iTunesEndPoint {

        var endpoint = iTunesEndPoint.AppID
        
        if appID == nil, let bundleid = NSBundle.mainBundle().bundleIdentifier{
            
            endpoint = iTunesEndPoint.BundleID
        }
        
        return endpoint
    }
    
    private var JSONCache : [NSObject : AnyObject]?
    
    
// MARK: - ## Download AppStore ##
    
    private func downloadAppInfo(completion:(Bool)->Void) {
        
        var id = appID
        
        if id == nil, let bundleid = NSBundle.mainBundle().bundleIdentifier{
            
            id = bundleid
        }
        
        request(Method.GET, endpoint.URL(id: id!), parameters: nil, encoding: ParameterEncoding.JSON).responseJSON(options: NSJSONReadingOptions.AllowFragments) { (req, res, json, error) -> Void in
            
            if let data = json as? [NSObject : AnyObject],
                let results = data[AppVersionChecker.kAppStoreResultsKey] as? NSArray,
                let result = results.firstObject as? [NSObject : AnyObject]{
                    self.JSONCache = result
                    completion(true)
                    
            } else {
                
                completion(false)
            }
        }
    }
    
    private func downloadCurrentAppStoreVersion(completion:(Bool,String?)->Void) {
        
        if JSONCache != nil,let version = JSONCache![AppVersionChecker.kAppStoreVersionKey] as? String{
            
            completion(true,version)
            return
        }
        
        downloadAppInfo { (success) -> Void in
            
            if success && self.JSONCache != nil,let version = self.JSONCache![AppVersionChecker.kAppStoreVersionKey] as? String {
                
                completion(success,version)
            } else {
                completion(false,nil)
            }
        }
        
    }
    
    private func downloadReleaseNotes(completion:(Bool,String?)->Void) {
        
        if JSONCache != nil,let notes = JSONCache![AppVersionChecker.kAppStoreReleaseNotesKey] as? String{
            
            completion(true,notes)
            return
        }
        
        downloadAppInfo { (success) -> Void in
            
            if success && self.JSONCache != nil,let notes = self.JSONCache![AppVersionChecker.kAppStoreReleaseNotesKey] as? String {
                
                completion(success,notes)
            } else {
                completion(false,nil)
            }
        }
        
    }
    
// MARK: - ## Public method ##
    
    /**
    Check for that current version was updated latest version.
    If already updated to latest version, display the release notes from AppStore data.
    And to request for required version from JSON file or AppStore data.
    
    */
    public func check() {
        
        self.checkReleaseNotesIfNeeded(currentVersion)
        self.checkRequiredVersion()
    }
    
// MARK: - ## Check Required Version ##
    
    // { "version" : string, "optional" : boolean}
    private func checkRequiredVersion() {
        
        if let url = NSURL(string: jsonURL) {
            
            checkURLForRequiredVersion(jsonURL: url)
            
        } else {
            
            checkAppStoreForRequiredVersion()
        }
    }
    
    private func checkAppStoreForRequiredVersion(){
        
        showUpdateIfNeeded(currentVersion, optional: true)
    }
    
    private func checkURLForRequiredVersion(jsonURL URL:NSURL) {
        
        request(Method.GET, URL, parameters: nil, encoding: ParameterEncoding.JSON).responseJSON(options: NSJSONReadingOptions.AllowFragments) { (req, res, json, error) -> Void in
            
            if error != nil {
                println(error)
                return
            }
            
            if let data = json as? NSDictionary,
                let version = data[AppVersionChecker.kVersion] as? String  ,
                let optional = data[AppVersionChecker.kOptional] as? Bool {
                    
                    self.showUpdateIfNeeded(version, optional: optional)
                    
            }
        }
    }
    
    private func showUpdateIfNeeded(version:String,optional:Bool) {
        
        downloadCurrentAppStoreVersion { (success, storeVersion) -> Void in
            
            if !success || storeVersion == nil {
                return
            }
            
            if version.compare(storeVersion!, options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedAscending {
         
                if self.isNeedUpdate(version) {
                    
                    self.downloadAppInfo({ (success) -> Void in
                        
                        if let json = self.JSONCache, let str = json[AppVersionChecker.kAppStoreURLKey] as? String, let url = NSURL(string: str)  {
                            
                            self.showAlert(optional,storeURL:url)
                        }
                    })
                }
                
            }
        }
    }
    
    private func showAlert(optional:Bool,storeURL:NSURL) {
        
        var title = alertTitle
        if title.isEmpty {
            
            title = NSLocalizedString("AppVersionChecker.title", tableName: "AppVersionChecker", bundle: NSBundle.AppVersionCheckerBundle(),comment: "")
        }
        
        var message = alertBody
        if message.isEmpty {
            
            message = NSLocalizedString("AppVersionChecker.body", tableName: "AppVersionChecker", bundle: NSBundle.AppVersionCheckerBundle(),comment: "")
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        if optional {
            
            var later = NSLocalizedString("AppVersionChecker.button.later", tableName: "AppVersionChecker", bundle: NSBundle.AppVersionCheckerBundle(),comment: "")
            
            alert.addAction(UIAlertAction(title: later, style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
                
            }))
        }
        
        var update = NSLocalizedString("AppVersionChecker.button.update", tableName: "AppVersionChecker", bundle: NSBundle.AppVersionCheckerBundle(),comment: "")
        
        alert.addAction(UIAlertAction(title: update, style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            
            if UIApplication.sharedApplication().canOpenURL(storeURL) {
                
                UIApplication.sharedApplication().openURL(storeURL)
            }
        }))
        
        if let vc = UIApplication.sharedApplication().keyWindow?.rootViewController {
            
            vc.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    private func isNeedUpdate(version:String) -> Bool {
        
        let res = currentVersionCompare(version)
        
        switch res {
        case .OrderedAscending :
            return true
        default :
            return false
        }
    }
    
    private func currentVersionCompare(version:String) -> NSComparisonResult {
        
        return currentVersion.compare(version, options: NSStringCompareOptions.NumericSearch)
        
    }
    
// MARK: - ## Check ReleaseNotes ##
    private func checkReleaseNotesIfNeeded(version:String) {
        
        if isFirstLaunch(inThisVersion: version) {
            
            downloadReleaseNotes({ (success, notes) -> Void in
                
                if success && notes != nil,
                    let storeVersion = self.JSONCache![AppVersionChecker.kAppStoreVersionKey] as? String{
                    
                        if storeVersion.compare(self.currentVersion, options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedSame {
                            
                            self.showNotes(version, notes: notes!)
                        }
                }
            })
        }
    }
    
    private func showNotes(version:String,notes:String) {
        
        let alert = UIAlertController(title: version, message: notes, preferredStyle: UIAlertControllerStyle.Alert)
        
        var ok = NSLocalizedString("AppVersionChecker.button.ok", tableName: "AppVersionChecker", bundle: NSBundle.AppVersionCheckerBundle(),comment: "")
        
        alert.addAction(UIAlertAction(title: ok, style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            
            self.didFinishLaunch(inThisVersion: version)
            
        }))
        
        if let vc = UIApplication.sharedApplication().keyWindow?.rootViewController {
            
            vc.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    private func didFinishLaunch(inThisVersion version:String) {
        
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "DidFinishFirstLaunch" + version)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    private func isFirstLaunch(inThisVersion version:String) -> Bool {
        
        if NSUserDefaults.standardUserDefaults().boolForKey("DidFinishFirstLaunch" + version) {
            return false
        }
        
        return true
    }
}

extension NSBundle {
    
    private class func AppVersionCheckerBundle() -> NSBundle {
        
        return NSBundle(forClass: AppVersionChecker.self)
    }
    
    private class func currentVersion() -> String {
        
        if let dic = NSBundle(forClass: AppVersionChecker.self).infoDictionary as [NSObject : AnyObject]!,
            let current = dic["CFBundleShortVersionString"] as? String  {
                return current
        }
        
        return ""
    }
    
}