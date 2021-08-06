require 'httparty'

# Return array of hashes with keys:
# :name, :expiration_date, :description, :phone, :url, :island, :address

def vaccines_gov

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
			name: provider[:name],
			expiration_date: "",
			description: description,
			phone: provider[:phone],
			url: provider_url,
			island: "",
			address: "#{provider[:address1]} #{provider[:address2]}, #{provider[:city]}, #{provider[:state]}, #{provider[:zip]}"
		}
		final_rows << final_row
	end

	return final_rows

end

vaccines_gov