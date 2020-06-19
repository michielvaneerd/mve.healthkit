# mve.healthkit

Titanium module that reads different types of quantity data from HealthKit.

## Getting Started

1. Build this project or download the module from the `dist` directory.
2. Require the module.
3. Add the `com.apple.developer.healthkit` entitlement to tiapp.xml (see the [tiapp.xml](example_not_included/tiapp.xml) in the example project).
4. Add the `NSHealthShareUsageDescription` key to tiapp.xml (see the [tiapp.xml](example_not_included/tiapp.xml) in the example project).
5. Call `isHealthDataAvailable` to see if HealthKit is available on the device.
6. Call `fetchData` to get the data you need.

## API

### isHealthDataAvailable()

Checks if HealthKit is available on the device. For example iPads don't have HealthKit. Returns a boolean.

### getTimeUnits()

Returns an array of time units you can use in the `fetchData` function.

### getQuantityTypeIdentifiers()

Returns an array of quantityTypeIdentifiers you can use in the `fetchData` function.

### fetchData(arg)

Fetches the requested quantity data from HealthKit and calls the callback with the results.

* String `timeUnit` - See `getTimeUnits()` for valid values.
* String `quantityTypeIdentifier` - See `getQuantityTypeIdentifiers()` for valid values.
* Date `startDate` - The start date.
* Date `endDate` - The end date.
* Function `onSuccess` - Will be called with the result. The result is an array of key (ISO8601 date string) value (number) pairs.
* Optional Function `onError` - Will be called in case of an error.

## Building this module

Clone this project. Go inside the ios directory and do:

```
ti build -p ios --build-only
```

## License

This project is licensed under the GNU GPLv3 License - see the [LICENSE](LICENSE) file for details.
