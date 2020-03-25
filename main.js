$(function() {


	Tabletop.init({
		key: '1TpA6W7dMdj-IfflZZVdhgwZ_0UvvARd-3WCq8xXTt2E',
		callback: init

	});

	function init(data, tabletop) {
		console.log(data);
		console.log(tabletop);

		var locationData = tabletop.sheets('Resources').all();
		console.log(locationData)

		var spanTemplate = _.template("<span><%= value %></span>")

		var categories = _.chain(locationData).map(function(val) { return val.Category.trim()}).uniq().value().sort();
		categories.unshift("Everything");
		_(categories).each(function(category) {
			var html = spanTemplate({value: category});
			$('#category-list').append(html);
		});

		var locations = _.chain(locationData).map(function(val) { return val.Location.trim()}).uniq().filter(function(val){ return val != "Online" }).value().sort();
		locations.unshift("Online");
		locations.unshift("Everywhere");
		_(locations).each(function(category) {
			var html = spanTemplate({value: category});
			$('#location-list').append(html);
		});


		$.map(locationData, function(row) {
		})
	}

});