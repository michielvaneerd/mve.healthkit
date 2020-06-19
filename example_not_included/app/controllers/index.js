const hk = require("mve.healthkit");
const moment = require("/alloy/moment");

function doClick(e) {

	try {
		hk.fetchData({
			quantityTypeIdentifier: $.quantityType.value,
			timeFrame: "hourly",
			startDate: moment().subtract(7, 'd').toDate(),
			endDate: new Date(),
			onSuccess: callback,
			onError: function(error) {
				console.log(error)
			}
		});
	} catch (ex) {
		console.log("ERROR");
		console.log(ex);
	}
}

function callback(arg) {
	console.log("OK");
	console.log(arg);	
}

$.index.open();
