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
    static var workoutDict = [Int: HKWorkout]()
    
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
    
    @objc(fetchSessions:)
    func fetchSessions(arguments: Array<Any>?) {
        
        MveHealthkitModule.workoutDict.removeAll()
        
        guard let arguments = arguments, let params = arguments[0] as? [String: Any] else {
            return
        }
        
        // Optional parameter
        let sourceId = params["sourceId"] as? String
        let errorCallback = params["onError"] as? KrollCallback
        MveHealthkitModule.errorCallback = errorCallback
        
        guard
            let startDate = params["startDate"] as? Date,
            let endDate = params["endDate"] as? Date,
            let successCallback = params["onSuccess"] as? KrollCallback else {
            onError("Invalid parameters")
            return
        }
        
        let store = HKHealthStore()
        let sampleType = HKObjectType.workoutType()
        
        store.requestAuthorization(toShare: nil, read: [sampleType]) { (success: Bool, error: Error?) in
            
            if !success {
                self.onError(error?.localizedDescription ?? self.unknownError)
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let notMyAppPredicate = NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: .default()))
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, notMyAppPredicate])
            
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone.current
            
            var workoutResults = Array<[String: String]>()
            
            let query = HKSampleQuery(
            sampleType: sampleType, predicate: compoundPredicate, limit: 0, sortDescriptors: nil) {
                (query: HKSampleQuery, results: [HKSample]?, error: Error?) -> Void in
                
                var workoutCounter = 0
                
                if let results = results {
                    for result in results {
                        if let workout = result as? HKWorkout {
                            
                            if sourceId != nil && workout.sourceRevision.source.bundleIdentifier != sourceId {
                                continue
                            }
                            
                            workoutCounter += 1
                            
                            var dict = [String: String]()
                            dict["id"] = String(workoutCounter)
                            dict["name"] = workout.workoutActivityType.name
                            dict["startDate"] = formatter.string(from: workout.startDate)
                            dict["endDate"] = formatter.string(from: workout.endDate)
                            
                            workoutResults.append(dict)
                            
                            // Save for call to getHeartRateFromWorkout
                            MveHealthkitModule.workoutDict[workoutCounter] = workout
                            
                        }
                    }
                } else {
                    print("No results for workouts???")
                }
                
                DispatchQueue.main.async {
                    successCallback.call([
                        workoutResults
                    ], thisObject: nil)
                }
            }
            store.execute(query)
            
        }
        
    }
    
    @objc(fetckWorkoutData:)
    func fetckWorkoutData(arguments: Array<Any>?) {
        guard let arguments = arguments, let params = arguments[0] as? [String: Any] else {
            return
        }
        
        // Optional parameter
        let errorCallback = params["onError"] as? KrollCallback
        MveHealthkitModule.errorCallback = errorCallback
        
        guard
            let successCallback = params["onSuccess"] as? KrollCallback,
            let workoutId = params["id"] as? Int else {
            onError("Invalid parameters")
            return
        }
        
        if MveHealthkitModule.workoutDict[workoutId] == nil {
            onError("Unknown workout id")
            return
        }
        
        guard let workout = MveHealthkitModule.workoutDict[workoutId] else {
            onError("Unknown workout id")
            return
        }
        
        let typesToRead: Set<HKSampleType> = [HKObjectType.quantityType(forIdentifier: .heartRate)!]
        let store = HKHealthStore()
        
        store.requestAuthorization(toShare: nil, read: typesToRead) { (success: Bool, error: Error?) in
            
            if !success {
                self.onError(error?.localizedDescription ?? self.unknownError)
                return
            }
            
            guard let sampleType = HKSampleType.quantityType(forIdentifier: .heartRate) else {
                self.onError("Cannot create sampletype heartRate")
                return
            }
            
            let predicate = HKQuery.predicateForObjects(from: workout)
            let sortByDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: [sortByDate]) {
                query, results, error in
                
                if error != nil {
                    self.onError(error?.localizedDescription ?? self.unknownError)
                    return
                }
                
                guard let samples = results as? [HKQuantitySample] else {
                    self.onError("No results")
                    return
                }
            
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone.current
                var myResults = Array<[String: Int]>()
                
                for sample in samples {
                    
                    myResults.append([formatter.string(from: sample.endDate) : Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())))])
                    
//                    print("\(formatter.string(from: sample.startDate)) - \(formatter.string(from: sample.endDate)): \(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())))")
                }
                
                DispatchQueue.main.async {
                    successCallback.call([
                        myResults
                    ], thisObject: nil)
                }
            }
            
            store.execute(query)
            
        }
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

extension HKWorkoutActivityType {

    /*
     Simple mapping of available workout types to a human readable name.
     */
    var name: String {
        switch self {
        case .americanFootball:             return "American Football"
        case .archery:                      return "Archery"
        case .australianFootball:           return "Australian Football"
        case .badminton:                    return "Badminton"
        case .baseball:                     return "Baseball"
        case .basketball:                   return "Basketball"
        case .bowling:                      return "Bowling"
        case .boxing:                       return "Boxing"
        case .climbing:                     return "Climbing"
        case .crossTraining:                return "Cross Training"
        case .curling:                      return "Curling"
        case .cycling:                      return "Cycling"
        case .dance:                        return "Dance"
        case .danceInspiredTraining:        return "Dance Inspired Training"
        case .elliptical:                   return "Elliptical"
        case .equestrianSports:             return "Equestrian Sports"
        case .fencing:                      return "Fencing"
        case .fishing:                      return "Fishing"
        case .functionalStrengthTraining:   return "Functional Strength Training"
        case .golf:                         return "Golf"
        case .gymnastics:                   return "Gymnastics"
        case .handball:                     return "Handball"
        case .hiking:                       return "Hiking"
        case .hockey:                       return "Hockey"
        case .hunting:                      return "Hunting"
        case .lacrosse:                     return "Lacrosse"
        case .martialArts:                  return "Martial Arts"
        case .mindAndBody:                  return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
        case .paddleSports:                 return "Paddle Sports"
        case .play:                         return "Play"
        case .preparationAndRecovery:       return "Preparation and Recovery"
        case .racquetball:                  return "Racquetball"
        case .rowing:                       return "Rowing"
        case .rugby:                        return "Rugby"
        case .running:                      return "Running"
        case .sailing:                      return "Sailing"
        case .skatingSports:                return "Skating Sports"
        case .snowSports:                   return "Snow Sports"
        case .soccer:                       return "Soccer"
        case .softball:                     return "Softball"
        case .squash:                       return "Squash"
        case .stairClimbing:                return "Stair Climbing"
        case .surfingSports:                return "Surfing Sports"
        case .swimming:                     return "Swimming"
        case .tableTennis:                  return "Table Tennis"
        case .tennis:                       return "Tennis"
        case .trackAndField:                return "Track and Field"
        case .traditionalStrengthTraining:  return "Traditional Strength Training"
        case .volleyball:                   return "Volleyball"
        case .walking:                      return "Walking"
        case .waterFitness:                 return "Water Fitness"
        case .waterPolo:                    return "Water Polo"
        case .waterSports:                  return "Water Sports"
        case .wrestling:                    return "Wrestling"
        case .yoga:                         return "Yoga"
        
        // iOS 10
        case .barre:                        return "Barre"
        case .coreTraining:                 return "Core Training"
        case .crossCountrySkiing:           return "Cross Country Skiing"
        case .downhillSkiing:               return "Downhill Skiing"
        case .flexibility:                  return "Flexibility"
        case .highIntensityIntervalTraining:    return "High Intensity Interval Training"
        case .jumpRope:                     return "Jump Rope"
        case .kickboxing:                   return "Kickboxing"
        case .pilates:                      return "Pilates"
        case .snowboarding:                 return "Snowboarding"
        case .stairs:                       return "Stairs"
        case .stepTraining:                 return "Step Training"
        case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
        case .wheelchairRunPace:            return "Wheelchair Run Pace"
        
        // iOS 11
        case .taiChi:                       return "Tai Chi"
        case .mixedCardio:                  return "Mixed Cardio"
        case .handCycling:                  return "Hand Cycling"
        
        // iOS 13
        case .discSports:                   return "Disc Sports"
        case .fitnessGaming:                return "Fitness Gaming"
        
        // Catch-all
        default:                            return "Other"
        }
    }

}
