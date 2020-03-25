$(function() {
	var currentCategory = "category-everything";
	var currentLocation = "location-everywhere";


	Tabletop.init({
		key: '1TpA6W7dMdj-IfflZZVdhgwZ_0UvvARd-3WCq8xXTt2E',
		callback: init

	});

	function init(data, tabletop) {
		console.log(data);
		console.log(tabletop);

		var locationData = tabletop.sheets('Resources').all();
		console.log(locationData)

		// Add unique categories as buttons.
		var categories = _.chain(locationData).map(function(val) { return val.Category.trim()}).uniq().value().sort();
		categories.unshift("Everything");
		_(categories).each(function(category) {
			var html = "<span class='category-label " + parameterize('category', category) + "'>" + category + "</span>";
			$('#category-list').append(html);
		});

		// Add unique locations as buttons.
		var locations = _.chain(locationData).map(function(val) { return val.Location.trim()}).uniq().filter(function(val){ return val != "Online" }).value().sort();
		locations.unshift("Online");
		locations.unshift("Everywhere");
		_(locations).each(function(location) {
			var html = "<span class='location-label " + parameterize('location', location) + "'>" + location + "</span>";
			$('#location-list').append(html);
		});

		_(locationData).each(function(row) {
			var classes = ['row'];
			if (row.Category != "") {
				classes.push(parameterize('category', row.Category));
			}
			if (row.Location != "") {
				classes.push(parameterize('location', row.Location));
			}

			var html = "<div class='" + classes.join(' ') + "'>";
			html += "<header>";
			if (row.Category != "") {
				html += "<span class='category-label " + parameterize('category', row.Category) + "'>" + row.Category + "</span>";
			}
			if (row.Location != "") {
				html += "<span class='location-label " + parameterize('location', row.Location) + "'>" + row.Location + "</span>";
			}
			html += "<div class='row-title'>" + row.Name + "</div>";
			html += "</header>";
			html += "<div class='row-description'>"
			html += "<p>" + row.Description + "</p>";
			if (row.Phone != "") {
				html += "<p><span class='label'>Phone</span> " + row.Phone + "</span>";
			}
			if (row.Street != "" || row.City != "" || row.ZIP != "") {
				var address = _([row.Street, row.City, "HI", row.ZIP]).filter(function(val) { return val != "" }).join(", ");
				html += "<p><span class='label'>Address</span> " + address + "</span>";
			}
			if (row.URL != "") {
				html += "<p><a class='website-btn' href='" + row.URL + "' target='_blank'>Visit website</a></p>";
			}
			html += "</div></div>";
			$('#list').append(html);
		});

		updateFilter();
	}

	function parameterize(prefix, string) {
		var str = string.trim().toLowerCase().replace(/[^a-z0-9- ]/g, "").replace(/\s/g, "-");
		return prefix + "-" + str;
	}

	function updateFilter() {
		$('.category-label, .location-label').removeClass('selected');

		var selectedClasses = "";
		if (currentCategory != "") {
			$('span.' + currentCategory).addClass('selected');
			if (currentCategory != "category-everything") {
				selectedClasses += "." + currentCategory;	
			}
		}
		if (currentLocation != "") {
			$('span.' + currentLocation).addClass('selected');
			if (currentLocation != "location-everywhere") {
				selectedClasses += "." + currentLocation;
			}
		}

		console.log(selectedClasses);

		if ( currentCategory != "" || currentLocation != "") {
			$('.row').hide();
			$('.row' + selectedClasses).show();
		} else {
			$('.row').show();
		}
		
	}

	$('#list-wrap').on('click', '.category-label, .location-label', function() {
		var $this = $(this);
		if ($this.hasClass('category-label')) {
			// Category
			selectedCategory = parameterize('category', $(this).text());
			if (selectedCategory == currentCategory) {
				currentCategory = "category-everything";
			} else {
				currentCategory = selectedCategory;
			}
		} else {
			// Location
			selectedLocation = parameterize('location', $(this).text());
			if (selectedLocation == currentLocation) {
				currentLocation = "location-everywhere";
			} else {
				currentLocation = selectedLocation;
			}
		}
		updateFilter();
	});

});