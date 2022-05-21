$(function() {
	var currentType = "type-in-person";
	var currentCategory = "category-everything";
	var currentLocation = "location-everywhere";
	var markers = {};

	var windowWidth = $(window).width();
	var defaultZoom = 6;
	var locatedZoom = 13;
	if (windowWidth > 700) {
		defaultZoom = 7;
		locatedZoom = 14;
	}

	var otherLanguages;
	var otherLanguageTerms;
	var loadEnglish;

	var successRe = /^\#success/;
	var langRe = /lang-([a-zA-Z-]+)$/;


	var housingFinancialURL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=47580724&single=true&output=csv";
	var scrapedVaccineURL = "https://hcan-public-us-west.s3.amazonaws.com/covid_scraped_vaccines.json";
	var scrapedTestingURL = "https://hcan-public-us-west.s3.amazonaws.com/covid_scraped_testing.json";
	var testToTreatURL = "https://hcan-public-us-west.s3.amazonaws.com/covid_scraped_test_to_treat.json";
	var geoURL = "https://hcan-public-us-west.s3.amazonaws.com/covid_resource_locations.json";

	function getJSONPromise(url) {
		var d = $.Deferred();
		$.getJSON(url, function(data){
			d.resolve(data);
		});
		return d.promise();
	}

	if ( $("#list-financial-housing").length > 0 ) {
		// Get housing
		Papa.parse(housingFinancialURL, {
			download: true,
			header: true,
			complete: function(housingFinancialData) {
				init({housingFinancialData: housingFinancialData});
			}
		});

	}
	if ( $("#map-wrap-outer").length > 0 ) {
		// Get vaccines and testing
		$.when( getJSONPromise(scrapedVaccineURL), getJSONPromise(scrapedTestingURL), getJSONPromise(testToTreatURL), getJSONPromise(geoURL) )
			.done(function(scrapedVaccineData, scrapedTestingData, testToTreatData, geoData) {
				init({scrapedVaccineData: scrapedVaccineData,
					scrapedTestingData: scrapedTestingData,
					testToTreatData: testToTreatData,
					geoData: geoData});
			});
	}

	if ( $("#map").length > 0 ) {
		var map = L.map('map', {
			center: [21.311389, -157.796389],
			zoom: defaultZoom
		});
		if (map && navigator.geolocation) {
			$('#map-locate').data('status','active').show();
		}
		L.tileLayer('https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}', {
		    attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
		    maxZoom: 18,
		    id: 'mapbox/streets-v11',
		    tileSize: 512,
		    zoomOffset: -1,
		    accessToken: 'pk.eyJ1IjoicmNhdGFsYW5pLWhjYW4iLCJhIjoiY2s4NzJvM3piMGN0aDNsbmh3bGJ6bWJyNCJ9.RUI7xHjaMpxI4v-U0qKFBw'
		}).addTo(map);
	}

	function init(args) {

		var vaccineData = args.vaccineData;
		var testingData = args.testingData;
		var housingFinancialData = args.housingFinancialData;
		var scrapedVaccineData = args.scrapedVaccineData;
		var scrapedTestingData = args.scrapedTestingData;
		var testToTreatData = args.testToTreatData;
		var geoData = args.geoData;

		// console.log(scrapedVaccineData.data);
		// console.log(scrapedTestingData.data);

		// Fix:
		// Reassign old variables

		var categories = createCategories(["Vaccines (Ages 5+)", "Vaccines (Ages 18+)", "Testing", "Treatments"], "Everything", "#category-list-in-person");
		var onlineCategories = [];

		// --- Online categories
		if (housingFinancialData !== undefined) {
			var onlineCategoriesRaw = _(housingFinancialData.data).map(function(val) { return val.Category.trim()});
			onlineCategories = createCategories(onlineCategoriesRaw, "Everything", "#category-list-online");	
		}
		
		// Add unique locations as buttons.
		if (scrapedVaccineData !== undefined) {
			var onlyVaxLocations = _(scrapedVaccineData.data).map(function(val) { 
				if (val.Island !== null) {
					return val.Island.trim();	
				}
			});
			var onlyTestLocations = _(scrapedTestingData.data).map(function(val) {
				if (val.Island !== null) {
					return val.Island.trim();		
				}
			});
			var combinedLocations = onlyVaxLocations.concat(onlyTestLocations);
			var locations = createLocations(combinedLocations, "Everywhere", "Multiple Islands");	
		}

		// Get address lat/lngs
		// console.log(data);
		_(geoData).each(function(location) {
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

		loadEnglish = function(needsReset) {
			if (needsReset) {
				console.log("Need to fix this");
				// $('#list .only-in-person, #list .only-online, #category-list .only-in-person, #category-list .only-online, #location-list-inside').empty();

				// _(markers).each(function(value, key, list) {
				// 	map.removeLayer(value.marker);
				// });

				// $('.translatable').each(function(){
				// 	var text = $(this).data('original');
				// 	$(this).text(text);
				// });

				// categories = createCategories(combinedCategories, "Everything", "#category-list-in-person");
				// onlineCategories = createCategories(onlineCategoriesRaw, "Everything", "#category-list-online");
				// locations = createLocations(combinedLocations, "Everywhere", "Multiple Islands");
			}

			// Render rows
			if (scrapedVaccineData !== undefined) {
				vaccines18plus = _(scrapedVaccineData.data).filter(function(provider) {
					return !provider.Avail5to11;
				});
				vaccines5plus = _(scrapedVaccineData.data).filter(function(provider) {
					return provider.Avail5to11;
				});

				renderRows(vaccines18plus, "vax18plus", true, "#list .only-in-person", undefined, "Vaccines (Ages 18+)");
				renderRows(vaccines5plus, "vax5plus", true, "#list .only-in-person", undefined, "Vaccines (Ages 5+)");
				renderRows(scrapedTestingData.data, "testing", true, "#list .only-in-person", undefined, "Testing");
				renderRows(testToTreatData.data, "treatments", true, "#list .only-in-person", undefined, "Treatments");
			}
			
			if (housingFinancialData !== undefined) {
				renderRows(housingFinancialData.data, "online", false, "#list-financial-housing");	
			}
			

			// Assign colors
			assignCategoryColors([categories, onlineCategories], "Everything");

			updateFilter(true);
			$('.loading').slideUp(200);
			$('#list-inside').slideDown(200);	

			$("#lang-en").addClass('lang-active');
			// updateLanguageSwitcher('en', false);
		}

		if (langRe.test(location.hash)) {
			// Try other language
			tryOtherLanguage = true;
			lang = location.hash.match(langRe)[1];
			getLanguage(lang, function(present) {
				if (!present) {
					loadEnglish();
				}
			});
		} else {
			loadEnglish();
		}


		if ( $("#last-updated-date").length > 0 ) {
			$("#last-updated-date").text(scrapedVaccineData.lastUpdated);
		}

	}

	function renderRows(data, prefix, usingLocation, appendEl, terms, rowCategory) {
		if (terms == undefined) {
			terms = {
				phone: "Phone",
				address: "Address",
				visitWebsite: "Visit website",
				call: "Call",
				getDirections: "Get directions",
				findChildCare: "Find child care",
				childCare: "Child care"
			}
		}
		_(data).each(function(row, index) {
			var rowID = "row" + prefix + index;
			var hasLocation = false;
			var addressID;
			var address;
			var category;

			if (rowCategory == undefined) {
				category = row.Category;
			} else {
				category = rowCategory;
			}

			if (row.Name == undefined || row.Name == "") {
				return;
			}

			if (usingLocation && row.Address !== null) {
				addressID = row.Address.toLowerCase().replace(/[^a-z0-9_]/g, "");

				if (markers[addressID] !== undefined) {
					hasLocation = true;
					var marker = markers[addressID].marker;
					marker.addTo(map).on('click', markerClick);

					markers[addressID]['category'] = parameterize('category', category);
					markers[addressID]['location'] = parameterize('location', row.Island);

					$(marker._icon).addClass(parameterize('category', category));
					$(marker._icon).addClass(parameterize('location', row.Island));
					$(marker._icon).attr('id',rowID);
				}
			}

			var classes = ['row'];
			if (category != "") {
				classes.push(parameterize('category', category));
			}
			if (usingLocation && row.Island != "") {
				classes.push(parameterize('location', row.Island));
			}
			classes.push(rowID);

			var html = "<div class='" + classes.join(' ') + "'>";
			html += "<header";
			if (hasLocation) {
				html += " class='has-location' data-addressid='" + addressID + "'";
			}
			html += ">";
			if (category != "") {
				html += "<span class='category-label " + parameterize('category', category) + "'>" + category + "</span>";
			}
			if (usingLocation && row.Island != "") {
				html += "<span class='location-label " + parameterize('location', row.Island) + "'>" + row.Island + "</span>";
			}
			html += "<div class='row-title'>" + row.Name + "</div>";
			html += "</header>";
			html += "<div class='row-description'>"
			html += "<p>" + row.Description + "</p>";
			if (row.Phone != "") {
				html += "<p><span class='label'>" + terms.phone + "</span> " + row.Phone + "</span>";
			}
			if (usingLocation && row.Address != "" && row.Address !== undefined) {
				address = row.Address;
				html += "<p><span class='label'>" + terms.address + "</span> " + address + "</span>";
			}

			if (row.URL != "" || (usingLocation && (row.Address != "" && row.Address !== undefined)) || row.Phone != "" || category == terms.childCare) {
				html += "<p>";
				if (category == terms.childCare) {
					html += "<a class='action-btn' href='https://www.patchhawaii.org/find-child-care/' target='_blank'><i class='fas fa-info-circle'></i> " + terms.findChildCare + "</a>";
				}
				if (row.URL != "") {
					html += "<a class='action-btn' href='" + row.URL + "' target='_blank'><i class='fas fa-external-link-square-alt'></i> " + terms.visitWebsite + "</a>";
				}
				if (row.Phone != "") {
					html += "<a class='action-btn' href='tel:+1" + row.Phone + "'><i class='fa fa-phone-alt'></i> " + terms.call + "</a>";
				}
				if (usingLocation && (row.Address != "" && row.Address !== undefined)) {
					var googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=' + encodeURIComponent(address);
					html += "<a class='action-btn' href='" + googleMapsUrl + "' target='_blank'><i class='fa fa-map-marked'></i> " + terms.getDirections + "</a>";
				}
				html += "</p>";
			}
			
			html += "</div></div>";
			$(appendEl).append(html);
		});
	}

	function updateLanguageSwitcher(langCode, open) {

		var $wrap = $('#languages-wrap');
		$wrap.show();

		if (langCode != null) {
			var $el = $('#lang-' + langCode);
			if (!$el.hasClass('lang-active')) {
				$('.lang-option').each(function() {
					$(this).removeClass('lang-active');
				});
				$el.addClass('lang-active');
				getLanguage(langCode, function(present) {
					if (!present) {
						loadEnglish(true);
					}
				});
			}
		}

		if (open) {
			$wrap.children().show();
			$wrap.removeClass('closed').addClass('open');
		} else {
			$wrap.children().hide();
			$('#languages-wrap .lang-active').show();
			$wrap.removeClass('open').addClass('closed');
		}
	}

	function createCategories(categoriesData, everythingText, selector) {
		var categories = _(categoriesData).uniq();
		categories.unshift(everythingText);

		_(categories).each(function(category) {
			var categoryClass = category;
			if (categoryClass == everythingText) {
				categoryClass = "Everything";
			}
			var html = "<span class='category-label " + parameterize('category', categoryClass) + "'>" + category + "</span>";
			$(selector).append(html);
		});

		return categories;
	}

	function assignCategoryColors(categoriesArr,everythingText) {
		var allCategories = _.chain(categoriesArr).flatten().uniq().filter(function(val){ return val != everythingText }).value().sort();
		var colors = ["#e66101", "#5e3c99", "#d01c8b", "#018571"];

		_(allCategories).each(function(category, index) {
			var color = colors[index];
			$('span.'+parameterize('category', category)).css({
				'background-color': color,
				'color': '#fff'
			});
			$('.leaflet-marker-icon.'+parameterize('category', category)).css('color', color);
		});
	}

	function createLocations(locationsData, everywhereText, multipleIslandsText) {
		var locations = _.chain(locationsData).uniq().filter(function(val){ return (val != multipleIslandsText && val != "Multiple Islands" && val != "Online" && val != undefined && val != "") }).value().sort();
		locations.unshift(everywhereText);
		// locations.push(multipleIslandsText);
		_(locations).each(function(location) {
			var locationClass = location;
			if (locationClass == everywhereText) {
				locationClass = "Everywhere";
			} else if (locationClass == multipleIslandsText) {
				locationClass = "Multiple Islands";
			}

			var html = "<span class='location-label " + parameterize('location', locationClass) + "'>" + location + "</span>";
			$('#location-list-inside').append(html);
		});
		return locations;
	}

	function parameterize(prefix, string) {
		if (string != undefined) {
			var encoded = encodeURIComponent(string);
			var str = encoded.trim().toLowerCase().replace(/[^a-z0-9- ]/g, "").replace(/\s/g, "-");
			return prefix + "-" + str;	
		}
		return "";
	}

	function updateFilter(clear, scrollToList) {
		if (clear == undefined) {
			clear = false;
		}
		if (scrollToList == undefined) {
			scrollToList = false;
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
			if (map !== undefined) {
				map.flyTo([21.311389, -157.796389], defaultZoom, {duration: 0.75});		
			}
			
		}

		var scrollTop = 0;
		if (scrollToList) {
			scrollTop = $('#list').offset().top;
		}

		$('#map-wrap-outer, #list-wrap').animate({
			scrollTop: scrollTop
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
			var scroll = $row.offset().top - $('#list-wrap').offset().top + $('#list-wrap').scrollTop() + $('#map-wrap-outer').scrollTop();
			console.log($row.offset().top, $('#list-wrap').offset().top, $('#list-wrap').scrollTop(), $('#map-wrap-outer').scrollTop());
			console.log(scroll);

			// if (windowWidth < 700) {
			// 	scroll -= 300;
			// }

			$('#map-wrap-outer, #list-wrap').animate({
				scrollTop: scroll
			}, 250);
		}
		
		$('#map-reset').fadeIn(250);
	}

	function getLanguage(languageCode, outerCallback) {
		$('#list-inside').slideUp(200);
		$('.loading').slideDown(200);

		if (otherLanguages == undefined) {
			// First load
			var otherLanguagesURL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vSsAD49Z1N3k4Iu-tX4kXRgxZduW5FYwQ-5ts9NWQAUX8qyZourxwjF2HptoGmH6coBcUPp6psfh7XD/pub?output=csv";
			Papa.parse("onlineResourcesURL", {
				download: true,
				header: true,
				complete: function(terms) {
					otherLanguageTerms = _.chain(terms).map(function(obj){ return [obj["en"],obj] }).object().value();

					getLanguage(languageCode, outerCallback);
				}
			});

			// Tabletop.init({
			// 	key: '1SAgHX0KK7Cd5enyX6HtbFEXvgKGKfn3bOQ0wRgteIPg',
			// 	callback: function(data, tabletop) {
			// 		otherLanguages = tabletop;

			// 		var terms = otherLanguages.sheets("Terms").all();
			// 		otherLanguageTerms = _.chain(terms).map(function(obj){ return [obj["en"],obj] }).object().value();

			// 		getLanguage(languageCode, outerCallback);
			// 	}
			// });			
		} else {
			// Already loaded
			var langData = otherLanguages.sheets(languageCode);
			if (langData != undefined) {
				// Language exists

				// Translate site terms
				$('.translatable').each(function(){
					var text = $(this).text();
					if ( $(this).data('original') ) {
						text = $(this).data('original');
					}
					if ( otherLanguageTerms[text] != undefined ) {
						var translated = otherLanguageTerms[text][languageCode];
						if ( translated != undefined ) {
							$(this).data('original', text);
							$(this).text(translated);
						}
					}
				});

				_.defer(function(){
					// Render data

					$('#list .only-in-person, #list .only-online, #category-list .only-in-person, #category-list .only-online, #location-list-inside').empty();

					_(markers).each(function(value, key, list) {
						map.removeLayer(value.marker);
					});

					var everythingText = otherLanguageTerms["Everything"][languageCode];

					var inPersonData = _(langData.all()).filter(function(val){
						return val.Location != "";
					});
					var onlineData = _(langData.all()).filter(function(val){
						return val.Location == "";
					});

					var inPersonCategoriesRaw = _(inPersonData).map(function(val) { return val.Category.trim()});
					var inPersonCategories = createCategories(inPersonCategoriesRaw, everythingText, "#category-list-in-person");

					var onlineCategoriesRaw = _(onlineData).map(function(val) { return val.Category.trim()});
					var onlineCategories = createCategories(onlineCategoriesRaw, everythingText, "#category-list-online");

					var locationsRaw = _(inPersonData).map(function(val) { return val.Location.trim()});
					var locations = createLocations(locationsRaw, otherLanguageTerms["Everywhere"][languageCode], otherLanguageTerms["Multiple Islands"][languageCode]);

					var rowTerms = {
						phone: otherLanguageTerms["Phone"][languageCode],
						address: otherLanguageTerms["Address"][languageCode],
						visitWebsite: otherLanguageTerms["Visit website"][languageCode],
						call: otherLanguageTerms["Call"][languageCode],
						getDirections: otherLanguageTerms["Get directions"][languageCode],
						findChildCare: otherLanguageTerms["Find child care"][languageCode],
						childCare: otherLanguageTerms["Child care"][languageCode]
					};

					renderRows(inPersonData, "in-person", true, "#list .only-in-person", rowTerms);
					renderRows(onlineData, "online", false, "#list .only-online", rowTerms);
					assignCategoryColors([inPersonCategories, onlineCategories], everythingText);

					updateFilter();

					$('#list-inside').slideDown(200);
					$('.loading').slideUp(200);
					updateLanguageSwitcher(languageCode, false);
					location.hash = "#lang-" + languageCode;
					if (outerCallback != undefined) {
						outerCallback(true);	
					}
					
				})
			} else {
				if (outerCallback != undefined) {
					outerCallback(false);	
				}
				location.hash = "";
				$('#list-inside').slideDown(200);
				$('.loading').slideUp(200);
			}
		}
	
	}

	function getLocation() {
		var $el = $('#map-locate');
		if ($el.data('status') == 'active') {
			$el.data('status', 'loading');
			$el.html('<i class="fas fa-spinner fa-spin"></i>');
			navigator.geolocation.getCurrentPosition(success, error);
		}

		function success(position) {
			var lat  = position.coords.latitude;
			var lng = position.coords.longitude;
			map.flyTo([lat, lng], locatedZoom, {duration: 0.75});
			$('#map-reset').fadeIn(250);
			reset();
		}

		function error() {
			$el.html('<i class="fas fa-exclamation-circle"></i>');
			setTimeout(function() {
				reset();
			}, 1000);
		}

		function reset() {
			$el.data('status', 'active');
			$el.data('status', 'active');
			$el.html('<i class="fa fa-location-arrow"></i>');
		}
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
		var scrollToList = false;
		if ($this.hasClass('category-label')) {
			// Category
			selectedCategory = parameterize('category', $(this).text());
			if (selectedCategory == currentCategory || $this.hasClass('category-everything')) {
				currentCategory = "category-everything";
			} else {
				currentCategory = selectedCategory;
			}
		} else if ($this.hasClass('location-label')) {
			// Location
			selectedLocation = parameterize('location', $(this).text());
			if (selectedLocation == currentLocation || $this.hasClass('location-everywhere')) {
				currentLocation = "location-everywhere";
			} else if ( $this.hasClass(parameterize('location', 'multiple islands')) ) {
				currentLocation = parameterize('location', 'multiple islands');
			} else {
				currentLocation = selectedLocation;
			}
		} else if ($this.hasClass('type-label')) {
			// Type
			if ($this.hasClass('jump')) {
				currentType = $this.data('type');
				currentCategory = $this.data('category');
				currentLocation = $(this).data('location');
				scrollToList = true;
			} else if ($this.hasClass('type-in-person')) {
				currentType = 'type-in-person';
				clear = true;
			} else {
				currentType = 'type-online';
				clear = true;
			}
		}
		updateFilter(clear, scrollToList);
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
		// $('#updates-signup-wrap').show();
	}

	if (successRe.test(location.hash)) {
		$('#updates-signup-success-wrap').show();
		Cookies.set('hideSignup', 'true');
	}

	$('body').on('click', 'a', function(e) {
		try { 
			captureOutboundLink( $(this).attr('href') );
		} catch {
			console.log( $(this).attr('href') );
		}
	});

	$('.lang-option').click(function(){
		var open = $('#languages-wrap').hasClass('open');
		var langCode = $(this).attr('id').match(langRe)[1];

		updateLanguageSwitcher(langCode, !open);
	});

	$('#lang-close').click(function() {
		updateLanguageSwitcher(null, false);
	});

	$('#map-locate').click(function() {
		getLocation();
	});

	$(window).resize(calculateLayout);

});