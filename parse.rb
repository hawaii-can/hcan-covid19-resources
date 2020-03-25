require 'dotenv/load'
require 'json'
require 'smarter_csv'
require 'open-uri'
require 'httparty'
require 'aws-sdk-s3'
require 'mapbox-sdk'

def run
	# Setup
	Mapbox.access_token = ENV['MAPBOX_KEY']
	s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])
	location_csv_url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=0&single=true&output=csv"

	# Download existing parsed locations
	s3_locations_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_locations.json")
	s3_current_locations = JSON.parse(s3_locations_object.get.body.read, symbolize_names: true)
	current_address_ids = s3_current_locations.map{|r| r[:address_id]}

	# Download and parse Google Sheet
	open(location_csv_url, 'r:utf-8') do |f|
		rows = SmarterCSV.process(f)

		new_locations = rows.map do |row|
			# Generate address IDs
			street = row[:street]
			city = row[:city]
			zip = row[:zip]

			{
				address_id: "#{street}#{city}#{zip}".downcase.gsub(/\W/,''),
				address_str: "#{street} #{city} HI #{zip}"
			}
		end.select do |row|
			# Only select new addresses
			!current_address_ids.include? (row[:address_id])
		end.map do |row|
			# geocode
			lng_lat = geocode(row[:address_str])

			# Create array of hashes, each with {address_id, lat, lng}
			{
				address_id: row[:address_id],
				lng: lng_lat.first,
				lat: lng_lat.last
			}
		end

		# If any changes, upload to S3
		if new_locations.any?
			all_locations = s3_current_locations + new_locations
			s3_locations_object.put(body: all_locations.to_json)
		end
	end
end


def geocode(address_str)
	place = Mapbox::Geocoder.geocode_forward(address_str, limit: 1, country: 'US')
	return place.first["features"].first["center"]
end

run