$(function() {
	var currentType = "type-in-person";
	var currentCategory = "category-everything";
	var currentLocation = "location-everywhere";
	var markers = {};

	var windowWidth = $(window).width();
	var defaultZoom = 6;
	if (windowWidth > 700) {
		defaultZoom = 7;
	}

	Tabletop.init({
		key: '1TpA6W7dMdj-IfflZZVdhgwZ_0UvvARd-3WCq8xXTt2E',
		callback: init

	});

	var map = L.map('map', {
		center: [21.311389, -157.796389],
		zoom: defaultZoom
	})

	L.tileLayer('https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}', {
	    attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
	    maxZoom: 18,
	    id: 'mapbox/streets-v11',
	    tileSize: 512,
	    zoomOffset: -1,
	    accessToken: 'pk.eyJ1IjoicmNhdGFsYW5pLWhjYW4iLCJhIjoiY2s4NzJvM3piMGN0aDNsbmh3bGJ6bWJyNCJ9.RUI7xHjaMpxI4v-U0qKFBw'
	}).addTo(map);


	function init(data, tabletop) {
		// console.log(data);
		// console.log(tabletop);

		var locationData = tabletop.sheets('Resources').all();
		var foodData = tabletop.sheets('FoodResources').all();
		var onlineData = tabletop.sheets('OnlineResources').all();

		// Add unique categories as buttons.

		// --- Aggregate main and food spreadsheets.
		var onlyLocationCategories = _(locationData).map(function(val) { return val.Category.trim()});
		var onlyFoodCategories = _(foodData).map(function(val) { return val.Category.trim()});
		var combinedCategories = onlyLocationCategories.concat(onlyFoodCategories);
		var categories = _(combinedCategories).uniq().sort();

		categories.unshift("Everything");
		_(categories).each(function(category) {
			var html = "<span class='category-label " + parameterize('category', category) + "'>" + category + "</span>";
			$('#category-list-in-person').append(html);
		});

		// --- Online categories.
		var onlineCategories = _.chain(onlineData).map(function(val) { return val.Category.trim()}).uniq().value().sort();
		onlineCategories.unshift("Everything");
		_(onlineCategories).each(function(category) {
			var html = "<span class='category-label " + parameterize('category', category) + "'>" + category + "</span>";
			$('#category-list-online').append(html);
		});

		// Add unique locations as buttons.

		var onlyLocations = _(locationData).map(function(val) { return val.Location.trim()});
		var onlyFoodLocations = _(foodData).map(function(val) { return val.Location.trim()});
		var combinedLocations = onlyLocations.concat(onlyFoodLocations);
		var locations = _.chain(combinedLocations).uniq().filter(function(val){ return (val != "Online" && val != undefined && val != "") }).value().sort();
		locations.unshift("Everywhere");
		_(locations).each(function(location) {
			var html = "<span class='location-label " + parameterize('location', location) + "'>" + location + "</span>";
			$('#location-list').append(html);
		});

		// Get address lat/lngs
		$.getJSON("https://hcan-public-us-west.s3.amazonaws.com/covid_resource_locations.json", function(data) {
			// console.log(data);
			_(data).each(function(location) {
				if (location != null) {
					var icon =  L.divIcon({
						className: 'marker-icon',
						html: '<i class="fas fa-map-pin fa-3x"></i>',
						iconSize: [20,36],
						iconAnchor: [10,36]
					});

					var marker = L.marker([location.lat, location.lng],{
						icon: icon
					});
					markers[location.address_id] = {
						marker: marker
					}					
				}
			});
			// console.log(markers);


			// Render rows
			renderRows(locationData, "in-person", true, "#list .only-in-person");
			renderRows(foodData, "in-person-food", true, "#list .only-in-person");
			renderRows(onlineData, "online", false, "#list .only-online");

			updateFilter();
			$('#loading').slideUp(200);
			$('#list-inside').slideDown(200);

			// Assign colors
			var allCategories = _.chain([categories, onlineCategories]).flatten().uniq().filter(function(val){ return val != "Everything" }).value().sort();
			_(allCategories).each(function(category, index) {
				var val = (1.0 / allCategories.length) * index;
				var color = d3.interpolateViridis(val);
				$('span.'+parameterize('category', category)).css({
					'background-color': color,
					'color': '#fff'
				});
				$('.leaflet-marker-icon.'+parameterize('category', category)).css('color', color);
			});
		});

	}

	function renderRows(data, prefix, usingLocation, appendEl) {
		_(data).each(function(row, index) {
			var rowID = "row" + prefix + index;
			var hasLocation = false;
			var addressID;

			if (row.Name == undefined || row.Name == "") {
				return;
			}

			if (usingLocation) {
				addressID = [row.Street, row.City, row.ZIP].join('').toLowerCase().replace(/[^a-z0-9_]/g, "");

				if (markers[addressID] !== undefined) {
					hasLocation = true;
					var marker = markers[addressID].marker;
					marker.addTo(map).on('click', markerClick);

					markers[addressID]['category'] = parameterize('category', row.Category);
					markers[addressID]['location'] = parameterize('location', row.Location);

					$(marker._icon).addClass(parameterize('category', row.Category));
					$(marker._icon).addClass(parameterize('location', row.Location));
					$(marker._icon).attr('id',rowID);
				}
			}

			var classes = ['row'];
			if (row.Category != "") {
				classes.push(parameterize('category', row.Category));
			}
			if (usingLocation && row.Location != "") {
				classes.push(parameterize('location', row.Location));
			}
			classes.push(rowID);

			var html = "<div class='" + classes.join(' ') + "'>";
			html += "<header";
			if (hasLocation) {
				html += " class='has-location' data-addressid='" + addressID + "'";
			}
			html += ">";
			if (row.Category != "") {
				html += "<span class='category-label " + parameterize('category', row.Category) + "'>" + row.Category + "</span>";
			}
			if (usingLocation && row.Location != "") {
				html += "<span class='location-label " + parameterize('location', row.Location) + "'>" + row.Location + "</span>";
			}
			html += "<div class='row-title'>" + row.Name + "</div>";
			html += "</header>";
			html += "<div class='row-description'>"
			html += "<p>" + row.Description + "</p>";
			if (row.Phone != "") {
				html += "<p><span class='label'>Phone</span> " + row.Phone + "</span>";
			}
			if (usingLocation && (row.Street != "" || row.City != "" || row.ZIP != "")) {
				var address = _([row.Street, row.City, "HI", row.ZIP]).filter(function(val) { return val != "" }).join(", ");
				html += "<p><span class='label'>Address</span> " + address + "</span>";
			}
			if (row.URL != "") {
				html += "<p><a class='website-btn' href='" + row.URL + "' target='_blank'><i class='fas fa-external-link-square-alt'></i> Visit website</a></p>";
			}
			html += "</div></div>";
			$(appendEl).append(html);
		});
	}

	function parameterize(prefix, string) {
		if (string != undefined) {
			var str = string.trim().toLowerCase().replace(/[^a-z0-9- ]/g, "").replace(/\s/g, "-");
			return prefix + "-" + str;	
		}
		return "";
	}

	function updateFilter(clear) {
		if (clear == undefined) {
			clear = false;
		}

		$('.category-label, .location-label, .type-label').removeClass('selected');

		if (currentType != "") {
			$('span.' + currentType).addClass('selected');
			if (currentType == "type-in-person") {
				$('.only-in-person').show();
				$('.only-online').hide();
				$('#main-wrap').removeClass('hide-map');
			} else {
				$('.only-in-person').hide();
				$('.only-online').show();
				$('#main-wrap').addClass('hide-map');
			}
		}

		if (clear) {
			currentCategory = "category-everything";
			currentLocation = "location-everywhere";
		}

		var markerFilters = {};

		var selectedClasses = "";
		if (currentCategory != "") {
			$('span.' + currentCategory).addClass('selected');
			if (currentCategory != "category-everything") {
				selectedClasses += "." + currentCategory;	
				markerFilters['category'] = currentCategory;
			}
		}
		if (currentLocation != "") {
			$('span.' + currentLocation).addClass('selected');
			if (currentLocation != "location-everywhere") {
				selectedClasses += "." + currentLocation;
				markerFilters['location'] = currentLocation;
			}
		}

		// console.log(selectedClasses);

		if (selectedClasses != "") {
			// Perform filtering
			$('.row').hide();
			$('.row' + selectedClasses).show();

			$('.leaflet-marker-icon').hide();
			$('.leaflet-marker-icon' + selectedClasses).show();

			$('#map-reset').fadeIn(250);
		} else {
			// Everything selected, so show everything
			$('.row').show();
			$('.leaflet-marker-icon').show();
		}

		$('.row.map-selected').removeClass('map-selected');

		// Update markers
		var selectedMarkers = _(markers).where(markerFilters);
		// console.log(markers, markerFilters, selectedMarkers);
		if (selectedMarkers != undefined && selectedMarkers.length > 0) {
			var bounds = _(selectedMarkers).map(function(m) { return m.marker.getLatLng() });
			map.flyToBounds(bounds, {duration: 0.75});
		} else {
			map.flyTo([21.311389, -157.796389], defaultZoom, {duration: 0.75});	
		}

		
		$('html, body').animate({
			scrollTop: 0
		}, 250);
	}

	function markerClick(e) {
		var marker = e.target;
		highlightMarker(marker);
	}

	function highlightMarker(marker) {
		$('.selected-marker').removeClass('selected-marker');
		$(marker._icon).addClass('selected-marker');

		var id = $(marker._icon).attr('id');

		map.flyTo(marker.getLatLng(), 13, {duration: 0.75});

		var $row = $('.row.' + id);
		if ($row.length > 0) {
			$('.row.map-selected').removeClass('map-selected');
			$row.addClass('map-selected');
			var scroll = $row.offset().top;

			if (windowWidth <= 600) {
				scroll -= 300;
			}

			$('html, body').animate({
				scrollTop: scroll
			}, 250);
		}
		
		$('#map-reset').fadeIn(250);
	}

	var calculateLayout = _.debounce(function(){
		windowWidth = $(window).width();
	}, 300);

	var captureOutboundLink = function(url) {
	  gtag('event', 'click', {
	    'event_category': 'outbound',
	    'event_label': url,
	    'transport_type': 'beacon'
	  });
	}

	$('#list-wrap').on('click', '.category-label, .location-label, .type-label', function() {
		var $this = $(this);
		var clear = false;
		if ($this.hasClass('category-label')) {
			// Category
			selectedCategory = parameterize('category', $(this).text());
			if (selectedCategory == currentCategory) {
				currentCategory = "category-everything";
			} else {
				currentCategory = selectedCategory;
			}
		} else if ($this.hasClass('location-label')) {
			// Location
			selectedLocation = parameterize('location', $(this).text());
			if (selectedLocation == currentLocation) {
				currentLocation = "location-everywhere";
			} else {
				currentLocation = selectedLocation;
			}
		} else if ($this.hasClass('type-label')) {
			// Type
			selectedType = parameterize('type', $(this).text());
			currentType = selectedType;
			clear = true;
		}
		updateFilter(clear);
	});

	$('#list-wrap').on('click', '.has-location', function() {
		var addressID = $(this).data('addressid');
		if (markers[addressID] !== undefined) {
			var marker = markers[addressID].marker;
			highlightMarker(marker);
		}
	});	

	$('#map-reset').click(function(){
		currentCategory = "category-everything";
		currentLocation = "location-everywhere";
		$('.selected-marker').removeClass('selected-marker');
		updateFilter();
		$(this).fadeOut(250);
	})

	$('#show-embed').click(function(e) {
		e.preventDefault();
		$('#embed-wrap').fadeIn(250);
		return false;
	});

	$('.close').click(function(){
		var $closable = $(this).parents('.closable');
		$closable.fadeOut(250);
	});

	$('#updates-signup-hide').click(function() {
		Cookies.set('hideSignup', 'true', {expires: 14})
	});

	if ( Cookies.get('hideSignup') == undefined && location.hash != "#success" ) {
		$('#updates-signup-wrap').show();
	}

	if (location.hash == "#success") {
		$('#updates-signup-success-wrap').show();
		Cookies.set('hideSignup', 'true')
	}

	$('body').on('click', 'a', function(e) {
		try { 
			captureOutboundLink( $(this).attr('href') );
		} catch {
			console.log( $(this).attr('href') );
		}
	});


	$(window).resize(calculateLayout);

});