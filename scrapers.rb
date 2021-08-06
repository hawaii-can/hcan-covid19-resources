require 'dotenv/load'
require 'httparty'
require 'cgi'
require 'json'
require 'aws-sdk-s3'

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
	latlngs.each do |zip, latlng|
		lat = latlng.first
		lng = latlng.last
		url = "https://api.us.castlighthealth.com/vaccine-finder/v1/provider-locations/search?medicationGuids=779bfe52-0dd8-4023-a183-457eb100fccc,a84fb9ed-deb4-461c-b785-e17c782ef88b,784db609-dc1f-45a5-bad6-8db02e79d44f&lat=#{lat}&long=#{lng}&radius=100&appointments=false"

		response = HTTParty.get(url,
			headers:{ 'Content-Type' => 'application/json', 'Accept' => 'application/json'}
		)
		results_list = JSON.parse(response.body, symbolize_names: true)
		providers = results_list[:providers]
		all_providers.concat(providers)
	end

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
			"Address": "#{provider[:address1]} #{provider[:address2]}, #{provider[:city]}, #{provider[:state]}, #{provider[:zip]}"
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

save_data
