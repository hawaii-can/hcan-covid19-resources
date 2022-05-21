require 'dotenv/load'
require 'aws-sdk-s3'
require 'cgi'
require 'httparty'
require 'json'
require 'mapbox-sdk'
require 'open-uri'
require 'smarter_csv'

# Return array of hashes with keys:
# :name, :expiration_date, :description, :phone, :url, :island, :address

def vaccines_gov
	puts "Starting Vaccines.gov"

	all_providers = []
	final_rows = []

	latlngs = {
		"96720": [19.72, -155.09],
		"96732": [20.89, -156.44],
		"96748": [21.08, -157],
		"96813": [21.31, -157.86],
		"96766": [21.96, -159.35]
	}
	all_vax_codes = {
		"Pfizer-BioNTech (age 5-11)" => "25f1389c-5597-47cc-9a9d-3925d60d9c21",
		"Moderna (age 18+)" => "779bfe52-0dd8-4023-a183-457eb100fccc",
		"Pfizer-BioNTech (age 12+)" => "a84fb9ed-deb4-461c-b785-e17c782ef88b",
		"Johnson & Johnson/Janssen (age 18+)" => "784db609-dc1f-45a5-bad6-8db02e79d44f"
	}

	# All vaccines
	latlngs.each do |zip, latlng|
		lat = latlng.first
		lng = latlng.last
		vax_codes = all_vax_codes.values.join(",")
		url = "https://api.us.castlighthealth.com/vaccine-finder/v1/provider-locations/search?medicationGuids=#{vax_codes}&lat=#{lat}&long=#{lng}&radius=100&appointments=false"

		response = HTTParty.get(url,
			headers:{ 'Content-Type' => 'application/json', 'Accept' => 'application/json'}
		)
		results_list = JSON.parse(response.body, symbolize_names: true)
		providers = results_list[:providers]
		all_providers.concat(providers)
	end

	# Just kids 5-11
	kids_providers = []
	latlngs.each do |zip, latlng|
		lat = latlng.first
		lng = latlng.last
		vax_codes = all_vax_codes["Pfizer-BioNTech (age 5-11)"]
		url = "https://api.us.castlighthealth.com/vaccine-finder/v1/provider-locations/search?medicationGuids=#{vax_codes}&lat=#{lat}&long=#{lng}&radius=100&appointments=false"

		response = HTTParty.get(url,
			headers:{ 'Content-Type' => 'application/json', 'Accept' => 'application/json'}
		)
		results_list = JSON.parse(response.body, symbolize_names: true)
		providers = results_list[:providers]
		kids_providers.concat(providers)
	end
	kids_guids = kids_providers.map{|p| p[:guid]}

	all_providers = all_providers.uniq { |p| p[:guid] }
	all_providers.each do |provider|
		provider_url = "https://www.vaccines.gov/provider/?id=#{provider[:guid]}&medications=779bfe52-0dd8-4023-a183-457eb100fccc%2Ca84fb9ed-deb4-461c-b785-e17c782ef88b%2C784db609-dc1f-45a5-bad6-8db02e79d44f&radius=50&appointments=false"

		description = "Listed on Vaccines.gov."
		if provider[:accepts_walk_ins]
			description += " Walk-ins accepted."
		end
		if provider[:appointments_available]
			date_str = (Time.now.utc-10*60*60).strftime("%B %-d, %Y")
			description += " Appointments available as of #{date_str}."
		end

		final_row = {
			"Name": provider[:name],
			"Expiration date": "",
			"Description": description,
			"Phone": provider[:phone],
			"URL": provider_url,
			"Island": "",
			"Address": "#{provider[:address1]} #{provider[:address2]}, #{provider[:city]}, #{provider[:state]}, #{provider[:zip]}",
			"Avail5to11": kids_guids.include?(provider[:guid]),
			"Coordinates": [provider[:lat], provider[:long]]
		}
		final_rows << final_row
	end

	puts "Done."
	return final_rows
end

def oahu_vaccines
	puts "Starting Oahu vaccines"

	url = "https://www.easymapmaker.com/getmap/8d5600ec66dffba6017a63319f648c6a?1624998975"
	response = HTTParty.get(url)
	raw = response.body.match(/"dataLines":"(.+?)"/)[1]
	parsed = raw.gsub('\\/','/').split('\n').map{|r| r.split('\\t')}

	final_rows = []
	parsed.each do |row|
		final_row = {
			"Name": row[0],
			"Expiration date": "",
			"Description": "#{row[8]}. #{row[12]}. Listed on OneOahu.org.",
			"Phone": row[1],
			"URL": row[6],
			"Island": "Oʻahu",
			"Address": "#{row[2]}, #{row[3]}, #{row[4]} #{row[5]}"
		}
		final_rows << final_row
	end

	puts "Done."
	return final_rows
end

def hawaii_county(ics_url, source_url)
	puts "Starting Hawaii county: #{ics_url}"

	encoded_url = CGI.escape(ics_url)
	convert_url = "https://ical-to-json.herokuapp.com/convert.json?url=#{encoded_url}"
	response = HTTParty.get(convert_url)

	calendar = JSON.parse(response.body, symbolize_names:true)
	events = calendar[:vcalendar].first[:vevent]

	current_date = (Time.now.utc-10*60*60).strftime("%Y%m%d").to_i
	future_events = events.select{|e| e[:dtend][0].to_i > current_date }

	final_rows = []
	future_events.each do |event|
		final_row = {
			"Name": event[:summary],
			"Expiration date": "#{event[:dtend][0][0,4]}-#{event[:dtend][0][4,2]}-#{event[:dtend][0][6,2]}",
			"Description": event[:description].gsub('\n\n',". ").gsub('\,',',').gsub("</p><p>",". ").gsub(/<\/?p>/,""),
			"Phone": "",
			"URL": source_url,
			"Island": "Hawaiʻi",
			"Address": ""
		}
		final_rows << final_row
	end

	puts "Done."
	return final_rows
end

def maui_county
	puts "Starting Maui County vaccines"

	base_url = "https://#{ENV['MAUI_HOST']}/graphql"
	response = HTTParty.post(
		base_url,
		headers: {
			'Content-Type' => 'application/json; charset=UTF-8',
			'Accept' => 'application/json, text/plain, */*',
			'Accept-Encoding' => 'gzip, deflate, br',
			'Accept-Language' => 'en-us',
			'Host' => ENV['MAUI_HOST'],
			'Origin' => 'https://www.atlistmaps.com',
			'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
			'Connection' => 'keep-alive',
			'Referer' => 'https://www.atlistmaps.com/',
			'Content-Length' => '2402',
			'x-amz-user-agent' => 'aws-amplify/3.8.21 js',
			'X-Api-Key' => ENV['MAUI_KEY'],
		},
		body: '{"query":"query GetMap($id: ID!) {\n  getMap(id: $id) {\n    id\n    name\n    owner\n    markerColor\n    markerShape\n    markerSize\n    markerIcon\n    markerProgrammaticIconType\n    markerBorder\n    markerCustomImage\n    markerCustomIcon\n    markerCustomStyle\n    defaultZoom\n    gestureHandling\n    zoomHandling\n    zoomControl\n    fullscreenControl\n    streetViewControl\n    mapType\n    showTraffic\n    showTransit\n    showBicycling\n    showSidebar\n    showModals\n    showDirectionsButton\n    showSearchbox\n    showCurrentLocation\n    showTitle\n    showLightbox\n    showBranding\n    highlightSelectedMarker\n    permission\n    password\n    mapStyle\n    mapStyleGenerated\n    mapStyleRoads\n    mapStyleLandmarks\n    mapStyleLabels\n    mapStyleIcons\n    modalPosition\n    modalBackgroundColor\n    modalPadding\n    modalRadius\n    modalShadow\n    modalTail\n    modalTitleVisible\n    modalTitleColor\n    modalTitleSize\n    modalTitleWeight\n    modalAddressVisible\n    modalAddressLink\n    modalAddressColor\n    modalAddressSize\n    modalAddressWeight\n    modalNoteVisible\n    modalNoteColor\n    modalNoteSize\n    modalNoteWeight\n    itemsOrder\n    groupsCollapsed\n    categories(limit: 1000) {\n      items {\n        id\n        name\n        collapsed\n        itemsOrder\n        markerColor\n        markerSize\n        markerIcon\n        markerProgrammaticIconType\n        markerShape\n        markerBorder\n        markerCustomImage\n        markerCustomIcon\n      }\n      nextToken\n    }\n    shapes(limit: 1000) {\n      items {\n        id\n        lat\n        long\n        zoom\n        name\n        paths\n        fill\n        stroke\n        color\n        width\n        height\n        type\n      }\n      nextToken\n    }\n    markers(limit: 1000) {\n      items {\n        id\n        name\n        lat\n        long\n        placeId\n        formattedAddress\n        notes\n        createdAt\n        color\n        icon\n        size\n        shape\n        border\n        customImage\n        customIcon\n        customStyle\n        useCoordinates\n        useHTML\n        images(limit: 1000) {\n          items {\n            id\n            name\n            image\n          }\n          nextToken\n        }\n      }\n      nextToken\n    }\n  }\n}\n","variables":{"id":"fa3472c7-e0d1-46cb-8d09-fa744a231258"}}'
	)
	data = JSON.parse(response.body, symbolize_names:true)
	markers = data[:data][:getMap][:markers][:items]

	final_rows = []
	markers.each do |marker|
		description = marker[:notes]
		begin
			description = marker[:notes].split(/<\/?[^>]*>/).reject{|s| s == ""}.map(&:strip).map{|s| s[s.length-1] != "." ? s+"." : s}.join(" ")
		rescue
			puts "Error"
		end

		final_row = {
			"Name": marker[:name],
			"Expiration date": "",
			"Description": description,
			"Phone": "",
			"URL": "https://www.mauinuistrong.info",
			"Island": "Maui",
			"Address": marker[:formattedAddress]
		}
		final_rows << final_row
	end

	puts "Done."
	return final_rows
end

def save_data
	s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])
	s3_vaccines_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_vaccines.json")
	s3_testing_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_testing.json")

	date_str = (Time.now.utc-10*60*60).strftime("%B %-d, %Y")

	hawaii_county_testing = hawaii_county("https://calendar.google.com/calendar/ical/hccdacovid19%40gmail.com/public/basic.ics", "https://coronavirus-response-county-of-hawaii-hawaiicountygis.hub.arcgis.com/pages/covid-19-testing")
	all_testing = {
		data: hawaii_county_testing,
		lastUpdated: date_str
	}

	hawaii_county_vaccines = hawaii_county("https://calendar.google.com/calendar/ical/u5jtbme8e9l0k4s67pdn1conuc%40group.calendar.google.com/public/basic.ics", "https://coronavirus-response-county-of-hawaii-hawaiicountygis.hub.arcgis.com/pages/vaccine-information")
	all_vaccines_data = [
		vaccines_gov,
		oahu_vaccines,
		maui_county,
		hawaii_county_vaccines
	].flatten
	all_vaccines = {
		data: all_vaccines_data,
		lastUpdated: date_str	
	}

	s3_vaccines_object.put(body: all_vaccines.to_json)
	s3_testing_object.put(body: all_testing.to_json)

	puts "Saved data."
end

def check_address(str)
	if str.nil?
		return ""
	end

	components = str.split(",").map(&:strip)
	if components.include?("HI") || components.include?("Hawaii") || str =~ /(HI|Hawaii) \d{5,}/
		return str
	else
		puts "Fixing address: #{str}"
		return "#{str}, Hawaii"
	end
end

def hawaiicovid9_data
	# Setup
	Mapbox.access_token = ENV['MAPBOX_KEY']
	s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])

	# Download existing parsed locations
	s3_locations_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_locations.json")
	s3_current_locations = JSON.parse(s3_locations_object.get.body.read, symbolize_names: true)
	current_address_ids = s3_current_locations.select{|l| !l.nil?}.map{|r| r[:address_id]}

	# Setup final locations
	all_vaccines_data = []
	all_testing_data = []
	all_test_to_treat_data = []

	new_locations = []

	puts "Starting vaccine_geojson_url"
	vaccine_geojson_url = "https://services.arcgis.com/HQ0xoN0EzDPBOEci/arcgis/rest/services/20210901_Vaccination_Campaign_Public_View/FeatureServer/0/query?f=geojson&cacheHint=true&maxRecordCountFactor=4&resultOffset=0&resultRecordCount=8000&where=(Status%20%3D%20%27Confirmed%27)%20OR%20(Status%20%3D%20%27Ongoing%20Provider%27)&orderByFields=OBJECTID&outFields=*&outSR=102100&spatialRel=esriSpatialRelIntersects"
	# Properties:
	# Island, Type, Address, City, Zipcode, Name, Provider, Days_Open, Hours, Website,
	# 	Notes ("Offering Vaccine to the 5-11 Population")
	fix_islands = {
		"Oahu" => "Oʻahu",
		"Hawaii" => "Hawaiʻi",
		"Kauai" => "Kauaʻi",
		"Molokai" => "Molokaʻi",
		"Lanai" => "Lānaʻi"
	}

	vaccine_response = HTTParty.get(vaccine_geojson_url)
	vaccine_data = JSON.parse(vaccine_response.body, symbolize_names: true)
	puts "Count: #{vaccine_data[:features].count}"
	vaccine_data[:features].each do |feature|
		properties = feature[:properties]
		avail5to11 = properties[:Notes] == "Offering Vaccine to the 5-11 Population"
		
		address = "#{properties[:Address]}, #{properties[:City]}, HI, #{properties[:Zipcode]}"
		coordinates_data = get_coordinates(address, s3_current_locations)
		coordinates = coordinates_data[:coordinates]
		new_locations << coordinates_data[:new_location] if !coordinates_data[:new_location].nil?

		final_row = {
			"Name": properties[:Name],
			"Expiration date": "",
			"Description": "Schedule: #{properties[:Days_Open]}. Hours: #{properties[:Hours]}. Provider: #{properties[:Provider]}. Type: #{properties[:Type]}. Listed on HawaiiCOVID19.com.",
			"Phone": "",
			"URL": properties[:Website],
			"Island": fix_islands[properties[:Island]],
			"Address": address,
			"RawCoordinates": feature[:geometry][:coordinates],
			"Coordinates": coordinates,
			"Avail5to11": avail5to11
		}
		all_vaccines_data << final_row
	end


	puts "Starting testing_popup_geojson_url"
	testing_popup_geojson_url = "https://services.arcgis.com/HQ0xoN0EzDPBOEci/arcgis/rest/services/Temporary_C19_Testing/FeatureServer/0/query?f=geojson&cacheHint=true&maxRecordCountFactor=4&resultOffset=0&resultRecordCount=8000&where=USER_Hours%20%3C%3E%20%27Not%20available%27&orderByFields=ObjectID&outFields=*&outSR=102100&spatialRel=esriSpatialRelIntersects"
	# Properties:
	# USER_PlaceN, USER_Street, USER_City, USER_Zip, USER_Hours, USER_Register (URL), USER_Instruct
	testing_popup_response = HTTParty.get(testing_popup_geojson_url)
	testing_popup_data = JSON.parse(testing_popup_response.body, symbolize_names: true)
	puts "Count: #{testing_popup_data[:features].count}"
	testing_popup_data[:features].each do |feature|
		properties = feature[:properties]

		address = "#{properties[:USER_Street]}, #{properties[:USER_City]}, HI, #{properties[:USER_Zip]}"
		coordinates_data = get_coordinates(address, s3_current_locations)
		coordinates = coordinates_data[:coordinates]
		new_locations << coordinates_data[:new_location] if !coordinates_data[:new_location].nil?

		final_row = {
			"Name": properties[:USER_PlaceN],
			"Expiration date": "",
			"Description": "Popup testing site. #{properties[:USER_Instruct]} Schedule: #{properties[:USER_Hours]}. Listed on HawaiiCOVID19.com.",
			"Phone": "",
			"URL": properties[:USER_Register],
			"Island": "",
			"Address": address,
			"RawCoordinates": feature[:geometry][:coordinates],
			"Coordinates": coordinates
		}
		all_testing_data << final_row
	end

	puts "Starting testing_clinics_geojson_url"
	testing_clinics_geojson_url = "https://services.arcgis.com/HQ0xoN0EzDPBOEci/arcgis/rest/services/COVID19_Screening_Clinics_View/FeatureServer/0/query?f=geojson&cacheHint=true&maxRecordCountFactor=4&resultOffset=0&resultRecordCount=8000&where=(FacT%20%3D%20%27Screening%20Clinic%27)%20OR%20(FacT%20%3D%20%27Temp%20Testing%27)&orderByFields=OBJECTID&outFields=*&outSR=102100&spatialRel=esriSpatialRelIntersects"
	# Properties:
	# FacName, Place_addr, Phone_1, Hours, Days, Directions (URL), Instru
	testing_clinics_response = HTTParty.get(testing_clinics_geojson_url)
	testing_clinics_data = JSON.parse(testing_clinics_response.body, symbolize_names: true)
	puts "Count: #{testing_clinics_data[:features].count}"
	testing_clinics_data[:features].each do |feature|
		properties = feature[:properties]

		address = check_address(properties[:Place_addr])
		coordinates_data = get_coordinates(address, s3_current_locations)
		coordinates = coordinates_data[:coordinates]
		new_locations << coordinates_data[:new_location] if !coordinates_data[:new_location].nil?

		final_row = {
			"Name": properties[:FacName],
			"Expiration date": "",
			"Description": "#{properties[:Instru]} Schedule: #{properties[:Days]}. Hours: #{properties[:Hours]}. Listed on HawaiiCOVID19.com.",
			"Phone": properties[:Phone_1],
			"URL": properties[:Directions],
			"Island": "",
			"Address": address,
			"RawCoordinates": feature[:geometry][:coordinates],
			"Coordinates": coordinates
		}
		all_testing_data << final_row
	end

	puts "Starting test to treat"
	test_to_treat_url = "https://healthdata.gov/resource/6m8a-tsjg.json?state=HI"
	# https://healthdata.gov/Health/COVID-19-Test-to-Treat/6m8a-tsjg
	test_to_treat_response = HTTParty.get(test_to_treat_url)
	test_to_treat_data = JSON.parse(test_to_treat_response.body, symbolize_names: true)
	puts "Count: #{testing_popup_data.count}"
	test_to_treat_data.each do |location|
		address = location.slice(:address1, :address2, :city, :state, :zip).join(", ")
		coordinates_data = get_coordinates(address, s3_current_locations)
		coordinates = coordinates_data[:coordinates]
		new_locations << coordinates_data[:new_location] if !coordinates_data[:new_location].nil?

		last_reported_date = Time.parse(location[:last_report_date]).strftime("%b %e, %Y")

		final_row = {
			"Name": location[:provider_name],
			"Description": "Received an order of Paxlovid or Lagevrio (molnupiravir) in the last two months and/or have reported availability of the oral antiviral medications within the last two weeks. Last reported date: #{last_reported_date}. according to HealthData.gov.",
			"Phone": "",
			"URL": "",
			"Island": "",
			"Address": address,
			"RawCoordinates": location[:geopoint][:coordinates],
			"Coordinates": coordinates
		}
		all_test_to_treat_data << final_row
	end


	s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])
	s3_vaccines_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_vaccines.json")
	s3_testing_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_testing.json")
	s3_test_to_treat_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_test_to_treat.json")

	date_str = (Time.now.utc-10*60*60).strftime("%B %-d, %Y")
	all_testing = {
		data: all_testing_data,
		lastUpdated: date_str
	}
	all_vaccines = {
		data: [all_vaccines_data, vaccines_gov].flatten,
		lastUpdated: date_str	
	}
	all_test_to_treat = {
		data: all_test_to_treat_data,
		lastUpdated: date_str
	}

	s3_vaccines_object.put(body: all_vaccines.to_json)
	s3_testing_object.put(body: all_testing.to_json)
	s3_test_to_treat_object.put(body: all_test_to_treat.json)

	puts "Saved scraped data."

	if new_locations.any?
		puts "New locations = #{new_locations}"
		all_locations = s3_current_locations + new_locations
		all_locations.select!{|l| !l.nil?}
		s3_locations_object.put(body: all_locations.to_json)
		puts "Saved new locations."
	else
		puts "No new locations."
	end
end

def get_coordinates(address, s3_current_locations)
	coordinates_data = {}
	if !address.nil?
		address_id = address.downcase.gsub(/\W/,'')
		if existingLatLng = s3_current_locations.find{|loc| loc[:address_id] == address_id}
			coordinates_data[:coordinates] = [existingLatLng[:lat], existingLatLng[:lng]]
		else
			lng_lat = geocode(address)
			new_location = {
				address_id: address_id,
				lng: lng_lat.first,
				lat: lng_lat.last
			}
			coordinates_data[:new_location] = new_location
			coordinates_data[:coordinates] = [new_location[:lat], new_location[:lng]]
		end
	end
	return coordinates_data
end

def geocode(address_str)
	puts "geocoding #{address_str}"
	begin
		place = Mapbox::Geocoder.geocode_forward(address_str, limit: 1, country: 'US')
		return place.first["features"].first["center"]
	rescue StandardError => error
		puts "Error: #{error.inspect}"
		return nil
	end
end

# save_data
hawaiicovid9_data