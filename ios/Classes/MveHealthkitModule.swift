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

@available(iOS 10.0, *)
@objc(MveHealthkitModule)
class MveHealthkitModule: TiModule {
    
    enum TimeUnit: String, CaseIterable {
        case hourly, daily, weekly, monthly, yearly
    }
    
    let unknownError = "Unknown error"
    static var errorCallback: KrollCallback? = nil
    
    // See startUp() where conditional keys are added
    var quantityOptionDict = [
        HKQuantityTypeIdentifier.stepCount: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.heartRate: HKStatisticsOptions.discreteAverage,
        HKQuantityTypeIdentifier.activeEnergyBurned: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.appleExerciseTime: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.distanceWalkingRunning: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.distanceCycling: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.pushCount: HKStatisticsOptions.cumulativeSum,
        HKQuantityTypeIdentifier.distanceWheelchair: HKStatisticsOptions.cumulativeSum
    ]
    
    // See startUp() where conditional keys are added
    var quantityCountFuncDict = [
        HKQuantityTypeIdentifier.stepCount: { HKUnit.count() },
        HKQuantityTypeIdentifier.heartRate: { HKUnit.count().unitDivided(by: HKUnit.minute()) },
        HKQuantityTypeIdentifier.activeEnergyBurned : { HKUnit.kilocalorie() },
        HKQuantityTypeIdentifier.appleExerciseTime : { HKUnit.minute() },
        HKQuantityTypeIdentifier.distanceWalkingRunning: { HKUnit.meterUnit(with: .kilo) }, // or mile() or meter()?
        HKQuantityTypeIdentifier.distanceCycling: { HKUnit.meterUnit(with: .kilo) }, // or mile() or meter()?
        HKQuantityTypeIdentifier.distanceWheelchair: { HKUnit.meterUnit(with: .kilo) }, // or mile() or meter()?
        HKQuantityTypeIdentifier.pushCount: { HKUnit.count() }
    ];
    
    // ******************************************
    // Start functions created by Titanium module
    // ******************************************
    
    func moduleGUID() -> String {
        return "3912394f-db98-4ca7-af7a-9ddb8123462c"
    }
    
    override func moduleId() -> String! {
        return "mve.healthkit"
    }

    override func startup() {
        super.startup()
        myInitialize()
    }
    
    // ***********************
    // Start private functions
    // ***********************
    
    private func getStatisticsQuantityFunc(statistics: HKStatistics, quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKQuantity? {
        switch quantityTypeIdentifier {
        case .stepCount, .activeEnergyBurned, .appleExerciseTime, .distanceWalkingRunning, .distanceCycling, .pushCount, .distanceWheelchair:
            return statistics.sumQuantity()
        case .heartRate:
            return statistics.averageQuantity()
        default:
            if #available(iOS 11.0, *) {
                switch quantityTypeIdentifier {
                case .restingHeartRate, .walkingHeartRateAverage:
                    return statistics.averageQuantity()
                default:
                    if #available(iOS 13.0, *) {
                        switch quantityTypeIdentifier {
                        case .appleStandTime:
                            return statistics.sumQuantity()
                        default:
                            return nil
                        }
                    }
                }
            }
            return nil
        }
    }
    
    private func myInitialize() {
        if #available(iOS 11.0, *) {
            quantityOptionDict[HKQuantityTypeIdentifier.restingHeartRate] = HKStatisticsOptions.discreteAverage
            quantityCountFuncDict[HKQuantityTypeIdentifier.restingHeartRate] = quantityCountFuncDict[HKQuantityTypeIdentifier.heartRate]
            quantityOptionDict[HKQuantityTypeIdentifier.walkingHeartRateAverage] = HKStatisticsOptions.discreteAverage
            quantityCountFuncDict[HKQuantityTypeIdentifier.walkingHeartRateAverage] = quantityCountFuncDict[HKQuantityTypeIdentifier.heartRate]
        }
        
        if #available(iOS 13.0, *) {
            quantityOptionDict[HKQuantityTypeIdentifier.appleStandTime] = HKStatisticsOptions.cumulativeSum
            quantityCountFuncDict[HKQuantityTypeIdentifier.appleStandTime] = { HKUnit.minute() }
        }
    }
    
    private func onError(_ message: String) {
        MveHealthkitModule.errorCallback?.call([["error": message]], thisObject: nil)
    }
    
    // ****************
    // Start public API
    // ****************
    
    /**
     Returns all available TimeUnit values that can be used.
    
     - Returns: Array of strings
    */
    @objc(getTimeUnits:)
    func getTimeUnits(unused: Any?) -> [String] {
        return Array(TimeUnit.allCases.map {
            $0.rawValue
        })
    }
    
    /**
     Returns all available HKQuantityTypeIdentifier values that can be used.
     
     - Returns: Array of strings
     */
    @objc(getQuantityTypeIdentifiers:)
    func getQuantityTypeIdentifiers(unused: Any?) -> [String] {
        return Array(quantityOptionDict.keys.map {
            $0.rawValue
        })
    }
    
    /**
     Checks if HealthKit is available.
     
     - Returns: True if HealthKit is enabled, false if it is not.
     */
    @objc(isHealthDataAvailable:)
    func isHealthDataAvailable(unused: Array<Any>?) -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /**
     Fetches requested quantity data.
     
     - Parameter arguments: Array. First item is a Dictionary<String, Any> with the following keys:
        - timeUnit: String. Valid values are from TimeUnit enum.
        - startDate: Date
        - endDate: Date
        - quantityTypeIdentifier: String. Valid values are returned from a call to getQuantityTypeIdentifiers().
        - onSuccess: KrollCallback. Will be called with 1 parameter Array<[String: Int]>
        - onError: KrollCallback?. Will be called with 1 parameter Dictionary<String, Any>. Only key is "error" with error message.
     */
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
            let timeUnitParam = params["timeUnit"] as? String,
            let timeUnit = TimeUnit(rawValue: timeUnitParam),
            let startDate = params["startDate"] as? Date,
            let endDate = params["endDate"] as? Date,
            let quantityTypeIdentifierParam = params["quantityTypeIdentifier"] as? String,
            let successCallback = params["onSuccess"] as? KrollCallback
        else {
            onError("Invalid parameters")
            return
        }
        
        // This will always succeed, hence no optional
        let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: quantityTypeIdentifierParam)
        
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
            switch timeUnit {
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
                
                var results = Array<[String: Int]>()
                
                collection.enumerateStatistics(from: startDate, to: endDate) { (statistics: HKStatistics, stop) in
                    
                    if let quantity = self.getStatisticsQuantityFunc(statistics: statistics, quantityTypeIdentifier: quantityTypeIdentifier) {
                        results.append([formatter.string(from: statistics.startDate): Int(quantity.doubleValue(for: self.quantityCountFuncDict[quantityTypeIdentifier]!()))])
                    }
                    
                }
                
                DispatchQueue.main.async {
                    successCallback.call([
                        results
                    ], thisObject: nil)
                }
                
            }
            
            store.execute(query)
            
        }
        
    }
  
}
