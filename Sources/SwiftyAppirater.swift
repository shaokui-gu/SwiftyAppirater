//
//  Popover.swift
//  Polytime
//
//  Created by gavin on 2021/12/19.
//  Copyright © 2021 cn.kroknow. All rights reserved.
//

import Foundation
import UIKit
import SystemConfiguration
import Reachability

@objc public protocol SwiftyAppiraterDelegate {
    func appiraterShouldDisplayAlert(_ irater:SwiftyAppirater) -> Bool
    func appiraterDidDisplayAlert(_ irater:SwiftyAppirater)
    func appiraterDidDeclineToRate(_ irater:SwiftyAppirater)
    func appiraterDidOptToRate(_ irater:SwiftyAppirater)
    func appiraterDidOptToRemindLater(_ irater:SwiftyAppirater)
    func appiraterWillPresentModalView(_ irater:SwiftyAppirater, animated:Bool)
    func appiraterDidDismissModalView(_ irater:SwiftyAppirater, animated:Bool)
}

let kAppiraterFirstUseDate = "kAppiraterFirstUseDate"
let kAppiraterUseCount = "kAppiraterUseCount"
let kAppiraterSignificantEventCount = "kAppiraterSignificantEventCount"
let kAppiraterCurrentVersion = "kAppiraterCurrentVersion"
let kAppiraterRatedCurrentVersion = "kAppiraterRatedCurrentVersion"
let kAppiraterDeclinedToRate = "kAppiraterDeclinedToRate"
let kAppiraterReminderRequestDate = "kAppiraterReminderRequestDate";


/*!
 Your localized app's name.
 */
let APPIRATER_LOCALIZED_APP_NAME = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String

/*!
 Your app's name.
 */
let APPIRATER_APP_NAME = APPIRATER_LOCALIZED_APP_NAME ?? (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? (Bundle.main.infoDictionary!["CFBundleName"] as! String)

/*!
 This is the message your users will see once they've passed the day+launches
 threshold.
 */

let APPIRATER_LOCALIZED_MESSAGE = NSLocalizedString("If you enjoy using %@, would you mind taking a moment to rate it? It won't take more than a minute. Thanks for your support!", tableName:"AppiraterLocalizable", bundle:SwiftyAppirater.instance.bundle, comment: "")

let APPIRATER_MESSAGE = String(format: APPIRATER_LOCALIZED_MESSAGE, APPIRATER_APP_NAME)

/*!
 This is the title of the message alert that users will see.
 */
let APPIRATER_LOCALIZED_MESSAGE_TITLE = NSLocalizedString("Rate %@", tableName:"AppiraterLocalizable", bundle:SwiftyAppirater.instance.bundle, comment: "")

let APPIRATER_MESSAGE_TITLE =  String(format: APPIRATER_LOCALIZED_MESSAGE_TITLE, APPIRATER_APP_NAME)

/*!
 The text of the button that rejects reviewing the app.
 */
let APPIRATER_CANCEL_BUTTON = NSLocalizedString("No, Thanks", tableName:"AppiraterLocalizable", bundle:SwiftyAppirater.instance.bundle, comment: "")
/*!
 Text of button that will send user to app review page.
 */
let APPIRATER_LOCALIZED_RATE_BUTTON = NSLocalizedString("Rate %@", tableName:"AppiraterLocalizable", bundle:SwiftyAppirater.instance.bundle, comment: "")
let APPIRATER_RATE_BUTTON = String(format: APPIRATER_LOCALIZED_RATE_BUTTON, APPIRATER_APP_NAME)

/*!
 Text for button to remind the user to review later.
 */
let APPIRATER_RATE_LATER = NSLocalizedString("Remind me later", tableName:"AppiraterLocalizable", bundle:SwiftyAppirater.instance.bundle, comment: "")

public class SwiftyAppirater : NSObject {
    
    public var appId:String = ""
    public var daysUntilPrompt:Double = 30
    public var usesUntilPrompt:Int = 20
    public var significantEventsUntilPrompt:Int = -1
    public var timeBeforeReminding:Double = 1
    public var debug:Bool = false
    public var usesAnimation = true
    private var statusBarStyle:UIStatusBarStyle = .default
    private var modalOpen:Bool = false
    public var alwaysUseMainBundle:Bool = false
    private var eventQueue:OperationQueue?
    
    public var alertTitle:String = APPIRATER_MESSAGE_TITLE
    public var alertMessage:String = APPIRATER_MESSAGE
    public var alertCancelTitle:String = APPIRATER_CANCEL_BUTTON
    public var alertRateTitle:String = APPIRATER_RATE_BUTTON
    public var alertRateLaterTitle:String = APPIRATER_RATE_LATER
    private let reachability:Reachability
    
    public var ratingAlert:UIAlertController?
    public var openInAppStore:Bool = true
    public weak var delegate:SwiftyAppiraterDelegate?
    
    public lazy var bundle:Bundle = {
        let bundle:Bundle
        if (alwaysUseMainBundle) {
            bundle = Bundle.main
        } else {
            let appiraterBundleURL = Bundle.main.url(forResource: "Appirater", withExtension: "bundle")
            if let appiraterBundleURL {
                // Appirater.bundle will likely only exist when used via CocoaPods
                bundle = Bundle(url: appiraterBundleURL)!
            } else {
                bundle = Bundle.main
            }
        }
        return bundle;
    }()
    
    public static let instance = SwiftyAppirater()
    
    private override init() {
        reachability = try! Reachability.init(hostname: "https://www.apple.com")
        eventQueue = OperationQueue()
        eventQueue!.maxConcurrentOperationCount = 1
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func appWillResignActive(_ notification:Notification) {
        if debug {
            print("APPIRATER appWillResignActive")
        }
        self.hideRatingAlert()
    }
    
    func connectedToNetwork() -> Bool {
        return reachability.connection != .unavailable
    }
}

extension SwiftyAppirater {
    
    func templateReviewURLForApp(_ appId:String) -> String {
        return "itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=\(appId)"
    }
    
    func templateReviewURLiOS7(_ appId:String) -> String {
        return "itms-apps://itms-apps://itunes.apple.com/app/\(appId)"
    }
    
    func templateReviewURLiOS8(_ appId:String) -> String {
        return "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=\(appId)&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
    }
}

import StoreKit
extension SwiftyAppirater {
    
    func showRatingAlert(_ displayRateLaterButton:Bool) {
        if !(delegate?.appiraterShouldDisplayAlert(self) ?? false) {
            return
        }
        self.rateApp()
        delegate?.appiraterDidDisplayAlert(self)
     }
    
    func showRatingAlert() {
        self.showRatingAlert(true)
    }
    
    func ratingAlertIsAppropriate() -> Bool {
        return self.connectedToNetwork()
                && !self.userHasDeclinedToRate()
                && !self.isRatingAlertVisible()
                && !self.userHasRatedCurrentVersion()
    }
    
    func ratingConditionsHaveBeenMet() -> Bool {
        guard !debug else {
            return true
        }
        
        let userDefaults = UserDefaults.standard
        let dateOfFirstLaunch = Date(timeIntervalSince1970: userDefaults.double(forKey: kAppiraterFirstUseDate))
        let timeSinceFirstLaunch = Date().timeIntervalSince(dateOfFirstLaunch)
        let timeUntilRate = 60 * 60 * 24 * daysUntilPrompt
        if timeSinceFirstLaunch < timeUntilRate {
            return false
        }
        // check if the app has been used enough
        let useCount = userDefaults.integer(forKey: kAppiraterUseCount)
        if useCount < usesUntilPrompt {
            return false
        }
        // check if the user has done enough significant events
        let sigEventCount = userDefaults.integer(forKey:kAppiraterSignificantEventCount)
        if sigEventCount < significantEventsUntilPrompt {
            return false
        }
        
        // if the user wanted to be reminded later, has enough time passed?
        let reminderRequestDate = Date.init(timeIntervalSince1970: userDefaults.double(forKey: kAppiraterReminderRequestDate))
        let timeSinceReminderRequest = Date().timeIntervalSince(reminderRequestDate)
        let timeUntilReminder = 60 * 60 * 24 * timeBeforeReminding
        if timeSinceReminderRequest < timeUntilReminder {
            return false
        }
        return false
    }
    
    func incrementUseCount() {
        // get the app's version
        let version =  Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        // get the version number that we've been tracking
        let userDefaults = UserDefaults.standard
        var trackingVersion = userDefaults.string(forKey: kAppiraterCurrentVersion)
        if trackingVersion == nil
        {
            trackingVersion = version;
            userDefaults.setValue(version, forKey: kAppiraterCurrentVersion)
        }
        
        if debug {
            print("APPIRATER Tracking version: \(trackingVersion ?? "")");
        }
        
        if trackingVersion == version {
            // check if the first use date has been set. if not, set it.
            var timeInterval = userDefaults.double(forKey: kAppiraterFirstUseDate)
            if timeInterval == 0 {
                timeInterval = Date().timeIntervalSince1970
                userDefaults.set(timeInterval, forKey: kAppiraterFirstUseDate)
            }
            
            // increment the use count
            let useCount = userDefaults.integer(forKey: kAppiraterUseCount) + 1
            userDefaults.setValue(useCount, forKey: kAppiraterUseCount)
            if debug {
                print("APPIRATER Use count: \(useCount)")
            }
        }
        else
        {
            // it's a new version of the app, so restart tracking
            userDefaults.setValue(version, forKey: kAppiraterCurrentVersion)
            userDefaults.setValue(Date().timeIntervalSince1970, forKey: kAppiraterFirstUseDate)
            userDefaults.setValue(1, forKey: kAppiraterUseCount)
            userDefaults.setValue(0, forKey: kAppiraterSignificantEventCount)
            userDefaults.setValue(false, forKey: kAppiraterRatedCurrentVersion)
            userDefaults.setValue(false, forKey: kAppiraterDeclinedToRate)
            userDefaults.setValue(Double(0), forKey: kAppiraterReminderRequestDate)
        }
        userDefaults.synchronize()
    }
    
    func incrementSignificantEventCount() {
        // get the app's version
        let version =  Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        // get the version number that we've been tracking
        let userDefaults = UserDefaults.standard
        var trackingVersion = userDefaults.string(forKey: kAppiraterCurrentVersion)
        if trackingVersion == nil
        {
            trackingVersion = version;
            userDefaults.setValue(version, forKey: kAppiraterCurrentVersion)
        }
        
        if debug {
            print("APPIRATER Tracking version: \(trackingVersion ?? "")");
        }
        
        if trackingVersion == version {
            // check if the first use date has been set. if not, set it.
            var timeInterval = userDefaults.double(forKey: kAppiraterFirstUseDate)
            if timeInterval == 0 {
                timeInterval = Date().timeIntervalSince1970
                userDefaults.set(timeInterval, forKey: kAppiraterFirstUseDate)
            }
            
            // increment the significant event count
            let sigEventCount = userDefaults.integer(forKey: kAppiraterSignificantEventCount) + 1
            userDefaults.setValue(sigEventCount, forKey: kAppiraterSignificantEventCount)
            if debug {
                print("APPIRATER Significant event count: \(sigEventCount)");
            }
        }
        else
        {
            // it's a new version of the app, so restart tracking
            userDefaults.setValue(version, forKey: kAppiraterCurrentVersion)
            userDefaults.setValue(Date().timeIntervalSince1970, forKey: kAppiraterFirstUseDate)
            userDefaults.setValue(0, forKey: kAppiraterUseCount)
            userDefaults.setValue(1, forKey: kAppiraterSignificantEventCount)
            userDefaults.setValue(false, forKey: kAppiraterRatedCurrentVersion)
            userDefaults.setValue(false, forKey: kAppiraterDeclinedToRate)
            userDefaults.setValue(Double(0), forKey: kAppiraterReminderRequestDate)
        }
        userDefaults.synchronize()
    }
    
    func incrementAndRate(_ canPromptForRating:Bool) {
        self.incrementUseCount()
        if canPromptForRating
            && self.ratingConditionsHaveBeenMet()
            && self.ratingAlertIsAppropriate()
        {
            DispatchQueue.main.async {
                self.showRatingAlert()
            }
        }
    }
    
    func incrementSignificantEventAndRate(_ canPromptForRating:Bool) {
        self.incrementSignificantEventCount()
        if canPromptForRating
            && self.ratingConditionsHaveBeenMet()
            && self.ratingAlertIsAppropriate()
        {
            DispatchQueue.main.async {
                self.showRatingAlert()
            }
        }
    }
    
    public func userHasDeclinedToRate() -> Bool {
        return UserDefaults.standard.bool(forKey: kAppiraterDeclinedToRate)
    }
    
    public func userHasRatedCurrentVersion()  -> Bool {
        return UserDefaults.standard.bool(forKey: kAppiraterRatedCurrentVersion)
    }
    
    func appLaunched(){
        self.appLaunched(true)
    }
    
    public func appLaunched(_ canPromptForRating:Bool) {
        DispatchQueue.global().async {
            let appirater = SwiftyAppirater.instance
            if appirater.debug {
                appirater.showRatingAlert()
            } else {
                appirater.incrementAndRate(canPromptForRating)
            }
        }
    }
    
    func isRatingAlertVisible() -> Bool {
        return self.ratingAlert?.view.superview != nil
    }
    
    func hideRatingAlert() {
        if self.isRatingAlertVisible() {
            if debug {
                print("APPIRATER Hiding Alert");
            }
            self.ratingAlert?.dismiss(animated: true)
        }
    }
    
   func appWillResignActive() {
       if debug {
           print("APPIRATER appWillResignActive");
       }
       SwiftyAppirater.instance.hideRatingAlert()
    }
    
    public func appEnteredForeground(_ canPromptForRating:Bool) {
        eventQueue?.addOperation({
            SwiftyAppirater.instance.incrementAndRate(canPromptForRating)
        })
    }
    
    public func userDidSignificantEvent(_ canPromptForRating:Bool) {
        eventQueue?.addOperation({
            SwiftyAppirater.instance.incrementSignificantEventAndRate(canPromptForRating)
        })
    }
    
    func showPrompt() {
        self.tryToShowPrompt()
    }
    
    public func tryToShowPrompt() {
        self.showPromptWithChecks(true, displayRateLaterButton:true)
    }
    
    public func forceShowPrompt(_ displayRateLaterButton:Bool) {
        self.showPromptWithChecks(false, displayRateLaterButton:displayRateLaterButton)
    }
    
    func showPromptWithChecks(_ withChecks:Bool, displayRateLaterButton:Bool) {
        if withChecks == false || self.ratingAlertIsAppropriate() {
            self.showRatingAlert(displayRateLaterButton)
        }
    }
    
    func getRootViewController() -> UIViewController? {
        let window = UIApplication.shared.windows.first
        if let window, window.windowLevel != .normal {
            let windows = UIApplication.shared.windows
            for window in windows {
                if window.windowLevel == .normal {
                    break
                }
            }
        }
        
        return self.iterateSubViewsForViewController(window)
    }
    
    func iterateSubViewsForViewController(_ parentView:UIView?) -> UIViewController?  {
        for subView in (parentView?.subviews ?? []) {
            let responder = subView.next
            if let vc = responder as? UIViewController {
                return self.topMostViewController(vc)
            }
            let found = self.iterateSubViewsForViewController(subView)
            if found != nil {
                return found
            }
        }
        return nil
    }
    
    func topMostViewController(_ vc:UIViewController?) -> UIViewController?  {
        var newVc = vc
        var isPresenting = false
        while isPresenting {
            // this path is called only on iOS 6+, so -presentedViewController is fine here.
            let presented = newVc?.presentedViewController
            isPresenting = presented != nil;
            if(presented != nil) {
                newVc = presented
            }
        }
        return newVc
    }
    
    public func rateApp() {
        let userDefaults = UserDefaults.standard
        userDefaults.setValue(true, forKey: kAppiraterRatedCurrentVersion)
        userDefaults.synchronize()
        SKStoreReviewController.requestReview()
    }
}

extension SwiftyAppirater : SKStoreProductViewControllerDelegate {
    
    public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        self.closeModal()
    }
    
    
    //Close the in-app rating (StoreKit) view and restore the previous status bar style.
    public func closeModal() {
        if modalOpen {
            self.modalOpen = false
            // get the top most controller (= the StoreKit Controller) and dismiss it
            var presentingController =  UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            presentingController = self.topMostViewController(presentingController)
            presentingController?.dismiss(animated: usesAnimation) {
                self.delegate?.appiraterDidDismissModalView(self, animated: self.usesAnimation)
            }
        }
    }
}
