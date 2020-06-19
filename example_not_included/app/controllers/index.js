const hk = require("mve.healthkit");
const moment = require("/alloy/moment");

function doClick(e) {

	console.log(hk.getQuantityTypeIdentifiers());

	console.log(hk.getTimeUnits());

	hk.fetchData({
		quantityTypeIdentifier: $.quantityType.value,
		timeUnit: "hourly",
		startDate: moment().subtract(7, 'd').toDate(),
		endDate: new Date(),
		onSuccess: callback,
		onError: function(ex) {
			alert(ex.error);
		}
	});
}

function callback(arg) {
	console.log(arg);	
}

$.index.open();
