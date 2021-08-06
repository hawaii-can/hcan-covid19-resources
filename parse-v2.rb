require 'dotenv/load'
require 'json'
require 'smarter_csv'
require 'open-uri'
require 'httparty'
require 'aws-sdk-s3'
require 'mapbox-sdk'

def run(location_csv_url)
	# Setup
	Mapbox.access_token = ENV['MAPBOX_KEY']
	s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])

	# Download existing parsed locations
	s3_locations_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_locations.json")
	s3_current_locations = JSON.parse(s3_locations_object.get.body.read, symbolize_names: true)
	current_address_ids = s3_current_locations.select{|l| !l.nil?}.map{|r| r[:address_id]}

	# Get scraped data
	s3_vaccines_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_vaccines.json")
	scraped_vaccines = JSON.parse(s3_vaccines_object.get.body.read, symbolize_names: true)

	s3_testing_object = s3.bucket(ENV['S3_BUCKET']).object("covid_scraped_testing.json")
	scraped_testing = JSON.parse(s3_testing_object.get.body.read, symbolize_names: true)

	# Download and parse Google Sheet
	open(location_csv_url, 'r:utf-8') do |f|
		puts "opening #{location_csv_url}"
		rows = SmarterCSV.process(f)

		current_locations = rows.map do |row|
			# Generate address IDs
			address = row[:address]

			{
				address_id: address.downcase.gsub(/\W/,''),
				address_str: address
			}
		end

		scraped_locations = scraped_vaccines[:data].concat(scraped_testing[:data]).map do |row|
			address = row[:Address]
			{
				address_id: address.downcase.gsub(/\W/,''),
				address_str: address
			}
		end.reject{|row| row[:address_id] == "" }

		current_locations.concat(scraped_locations)

		new_locations = current_locations.select do |row|
			# Only select new addresses
			!current_address_ids.include? (row[:address_id])
		end.map do |row|
			# geocode
			lng_lat = geocode(row[:address_str])

			if !lng_lat.nil?
				# Create array of hashes, each with {address_id, lat, lng}
				{
					address_id: row[:address_id],
					lng: lng_lat.first,
					lat: lng_lat.last
				}
			else
				nil
			end
		end

		# If any changes, upload to S3
		if new_locations.any?
			puts "new locations = #{new_locations}"
			all_locations = s3_current_locations + new_locations
			all_locations.select!{|l| !l.nil?}
			s3_locations_object.put(body: all_locations.to_json)
		else
			puts "no new locations"
		end
	end
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

vaccine_sites = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=9793876&single=true&output=csv"
testing_sites = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=262006366&single=true&output=csv"

run(vaccine_sites)
run(testing_sites)