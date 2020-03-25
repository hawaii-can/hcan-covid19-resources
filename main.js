$(function() {

	Tabletop.init({
		key: '1TpA6W7dMdj-IfflZZVdhgwZ_0UvvARd-3WCq8xXTt2E',
		callback: init

	});

	function init(data, tabletop) {
		console.log(data);
		console.log(tabletop);

		var locationData = tabletop.sheets('location-based').all();
		console.log(locationData);
	}

});