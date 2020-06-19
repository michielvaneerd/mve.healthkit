//
//  MveHealthkitModule.swift
//  mvehealthkit
//
//  Created by Michiel van Eerd
//  Copyright (c) 2020 Your Company. All rights reserved.
//

import UIKit
import TitaniumKit
import HealthKit

/**
 
 Titanium Swift Module Requirements
 ---
 
 1. Use the @objc annotation to expose your class to Objective-C (used by the Titanium core)
 2. Use the @objc annotation to expose your method to Objective-C as well.
 3. Method arguments always have the "[Any]" type, specifying a various number of arguments.
 Unwrap them like you would do in Swift, e.g. "guard let arguments = arguments, let message = arguments.first"
 4. You can use any public Titanium API like before, e.g. TiUtils. Remember the type safety of Swift, like Int vs Int32
 and NSString vs. String.
 
 */

@available(iOS 10.0, *)
@objc(MveHealthkitModule)
class MveHealthkitModule: TiModule {
    
    let unknownError = "Unknown error"
    static var errorCallback: KrollCallback? = nil
    
    let quantityOptionDict = [
        HKQuantityTypeIdentifier.stepCount: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.heartRate: HKStatisticsOptions.discreteAverage,
        HKQuantityTypeIdentifier.activeEnergyBurned: HKStatisticsOptions.cumulativeSum
    ]
    
    let quantityCountFuncDict = [
        HKQuantityTypeIdentifier.stepCount: { HKUnit.count() },
        HKQuantityTypeIdentifier.heartRate: { HKUnit.count().unitDivided(by: HKUnit.minute()) },
        HKQuantityTypeIdentifier.activeEnergyBurned : { HKUnit.kilocalorie() }
    ];
    
    private func getStatisticsQuantityFunc(statistics: HKStatistics, quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKQuantity? {
        switch quantityTypeIdentifier {
        case .stepCount, .activeEnergyBurned:
            return statistics.sumQuantity()
        case .heartRate:
            return statistics.averageQuantity()
        default:
            return nil
        }
    }
    
    enum TimeFrame: String {
        case hourly, daily, weekly, monthly, yearly
    }
  
    func moduleGUID() -> String {
        return "3912394f-db98-4ca7-af7a-9ddb8123462c"
    }
  
    override func moduleId() -> String! {
        return "mve.healthkit"
    }

    override func startup() {
        super.startup()
        debugPrint("[DEBUG] \(self) loaded")
    }
    
    private func onError(_ message: String) {
        MveHealthkitModule.errorCallback?.call([["error": message]], thisObject: self)
    }
    
    @objc(isHealthDataAvailable:)
    func isHealthDataAvailable(arguments: Array<Any>?) -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // TODO: How to name this method when it throws exceptions? @objc(fetchData::) doesn't work...
    @objc(fetchData:)
    func fetchData(arguments: Array<Any>?) {
        
        guard let arguments = arguments, let params = arguments[0] as? [String: Any] else {
            return
        }
        
        // Optional parameter
        let errorCallback = params["onError"] as? KrollCallback
        MveHealthkitModule.errorCallback = errorCallback
        
        // Required parameters
        guard
            let timeFrameParam = params["timeFrame"] as? String,
            let timeFrame = TimeFrame(rawValue: timeFrameParam),
            let startDate = params["startDate"] as? Date,
            let endDate = params["endDate"] as? Date,
            let quantityTypeIdentifierParam = params["quantityTypeIdentifier"] as? String,
            let successCallback = params["onSuccess"] as? KrollCallback
        else {
            onError("Invalid parameters")
            return
        }
        
        // This will always succeed, hence no optional
        let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: "HKQuantityTypeIdentifier" + (quantityTypeIdentifierParam.capitalizingFirstLetter()))
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
            onError("Invalid quantityTypeIdentifier")
            return
        }
        
        let store = HKHealthStore()
        
        let readData = Set<HKQuantityType>([quantityType])
        
        store.requestAuthorization(toShare: nil, read: readData) { (success: Bool, error: Error?) in
            
            if !success {
                self.onError(error?.localizedDescription ?? self.unknownError)
                return
            }
            
            let anchorDate: Date = Calendar.current.startOfDay(for: startDate)
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            
            var dateComponent = DateComponents()
            switch timeFrame {
            case .daily:
                dateComponent.day = 1
            case .hourly:
                dateComponent.hour = 1
            case .monthly:
                dateComponent.month = 1
            case .weekly:
                dateComponent.day = 7
            case .yearly:
                dateComponent.year = 1
            }
            
            let options = self.quantityOptionDict[quantityTypeIdentifier]!
            
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone.current
            
            let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options, anchorDate: anchorDate, intervalComponents: dateComponent)
            
            query.initialResultsHandler = { (query: HKStatisticsCollectionQuery, results: HKStatisticsCollection?, error: Error?) in
                
                if error != nil {
                    self.onError(error?.localizedDescription ?? self.unknownError)
                    return
                }
                
                guard let collection = results else {
                    self.onError("No results")
                    return
                }
                
                var results = [String: Int]()
                
                collection.enumerateStatistics(from: startDate, to: endDate) { (statistics: HKStatistics, stop) in
                    
                    if let quantity = self.getStatisticsQuantityFunc(statistics: statistics, quantityTypeIdentifier: quantityTypeIdentifier) {
                        results[formatter.string(from: statistics.startDate)] = Int(quantity.doubleValue(for: self.quantityCountFuncDict[quantityTypeIdentifier]!()))
                    }
                    
                }
                
                // Moet ik deze nu op UI thread aanroepen?
                successCallback.call([
                    results
                ], thisObject: self)
                
            }
            
            store.execute(query)
            
        }
          

        
    }
    
    @objc(anotherExample:)
    func anotherExample(arguments: Array<Any>?) -> String? {
        guard let arguments = arguments, let params = arguments[0] as? [String: Any] else { return nil }
        
        debugPrint(params["name"]!)
        return params["name"] as? String
    }
  
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
