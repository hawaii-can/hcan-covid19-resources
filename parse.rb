require 'dotenv/load'
require 'json'
require 'smarter_csv'
require 'open-uri'
require 'httparty'
require 'aws-sdk-s3'

s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])
s3_locations_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_locations.json")
location_csv_url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=0&single=true&output=csv"

# Download existing parsed locations
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

		"#{street}#{city}#{zip}".downcase.gsub(/\W/,'')
	end.select do |row|
		# Only select new addresses
		!current_address_ids.include? (row)
	end.map do |row|
		# geocode

		# Create array of hashes, each with {address_id, lat, lng}
		{
			address_id: address_id,
			lat: '999',
			lng: '999'
		}
	end

	# If any changes, upload to S3
	if new_locations.any?
		all_locations = s3_current_locations + new_locations
		s3_locations_object.put(body: all_locations.to_json)
	end
end