require 'dotenv/load'
require 'smarter_csv'
require 'open-uri'
require 'aws-sdk-s3'
require 'erb'
require 'httparty'
require 'time'
require 'sendgrid-ruby'
require 'base64'
include SendGrid

KEYS = [:description, :url, :phone, :street, :city, :zip]

def run
	s3 = Aws::S3::Resource.new(region: ENV['S3_REGION'])
	location_csv_url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=0&single=true&output=csv"
	online_csv_url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQm_HYq0rmBPR_Qc-M6F9IIJYTjv1aa4n-NRIodaVb4Jq64QVNeA89IPh80P_zbqQEDhcUB0Ab_Ju2Q/pub?gid=1922664152&single=true&output=csv"
	food_csv_url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vThJeclOOrsVQ9_gRu6UOSn2RqF94xoYKQpZMSWAUIUuhOt-_vQWxlQqI2UQM-3_3afwjZuINFJmBS8/pub?output=csv"

	s3_locations_data_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_locations_data.json")
	s3_online_data_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_online_data.json")
	s3_food_data_object = s3.bucket(ENV['S3_BUCKET']).object("covid_resource_food_data.json")

	new_or_changed = []

	new_locations = parse(location_csv_url)
	old_locations = get_object(s3_locations_data_object)
	new_or_changed << compare(new_locations, old_locations, 'In-Person')

	new_online = parse(online_csv_url)
	old_online = get_object(s3_online_data_object)
	new_or_changed << compare(new_online, old_online, 'Online')

	new_food = parse(food_csv_url)
	old_food = get_object(s3_food_data_object)
	new_or_changed << compare(new_food, old_food, 'Food')

	new_or_changed.flatten!

	if new_or_changed.any?

		if !ARGV[0].nil?
			recipients = [ {email: ARGV[0], first_name: "Test"} ]
			puts "Test: Overriding recipients: #{recipients}"
		else
			recipients = get_nb_tagged
			puts "Recipients: #{recipients}"
		end

		recipients.each do |recipient|
			puts recipient
			email_content = email(new_or_changed, recipient[:first_name])
			send_email(email_content, recipient[:email])
		end

		if !ARGV[0].nil?
			puts "Not updating JSON"
		else
			puts "Updating JSON"
			save_json(s3_locations_data_object, new_locations)
			save_json(s3_online_data_object, new_online)
			save_json(s3_food_data_object, new_food)
		end

	else
		puts "No changes"
	end

end

def parse(url)
	# Generates structure like:
	# 'NAME': {
	# 	description: 'DESCRIPTION',
	# 	url: 'URL',
	# 	etc... for all KEYS
	# }, ...

	open(url, 'r:utf-8') do |f|
		rows = SmarterCSV.process(f)
		results = {}

		rows.each do |row|
			next if row[:name].nil? || row[:name] == ""

			entry = {}
			name = row[:name].to_sym

			KEYS.each do |key|
				entry[key] = row[key]
			end

			results[name] = entry
		end

		return results
	end
end

def compare(new_entries, old_entries, resource_type)
	ret = []

	new_entries.each do |k, v|
		if old_entries[k] == nil
			# New
			changed = v
			changed[:name] = k
			changed[:status] = :new
			changed[:type] = resource_type
			ret << changed
		else
			# Exists, check changes
			changed = []
			KEYS.each do |key|
				if v[key] != old_entries[k][key]
					changed << true
				end
			end
			if changed.any?(true)
				changed = v
				changed[:name] = k
				changed[:status] = :changed
				changed[:type] = resource_type
				ret << changed
			end
		end
	end

	return ret
end

def save_json(s3_object, data)
	s3_object.put(body: data.to_json)
	puts "Saved JSON"
end

def get_object(s3_object)
	JSON.parse(s3_object.get.body.read, symbolize_names: true)
end	

def get_nb_tagged
	tag = "covid19_resources_updates"

	base_url = "https://#{ENV['NB_NATION']}.nationbuilder.com"
	tag_url = "#{base_url}/api/v1/tags/#{ERB::Util.url_encode(tag)}/people?limit=10&access_token=#{ENV['NB_TOKEN']}"

	# Get list of members via tag

	members = []

	more_results = true
	page = 1
	while more_results
		puts page
		page += 1

		puts tag_url

		tags_response = HTTParty.get(tag_url,
			headers:{ 'Content-Type' => 'application/json', 'Accept' => 'application/json'}
		)
		
		# puts tags_response.body, tags_response.code, tags_response.message, tags_response.headers.inspect

		tags_list = JSON.parse(tags_response.body, symbolize_names: true)
		tags_list[:results].each do |entity|
			if entity[:email_opt_in]
				member = {
					first_name: entity[:first_name],
					email: entity[:email]
				}
				members << member
			end
		end

		tag_url = "#{base_url}#{tags_list[:next]}&access_token=#{ENV['NB_TOKEN']}"
		more_results = !tags_list[:next].nil?
		# more_results = false # For debugging
	end

	return members
end

def address(entry)
	if entry[:type] == 'Online'
		return nil
	end
	address_components = [entry[:street], entry[:city], "HI", entry[:zip]]
	return address_components.select{|c| !c.nil? && c != "" }.join(', ')
end

def email(new_or_changed, recipient_name="friend")

	@recipient_name = recipient_name
	@new_entries = new_or_changed.select{|e| e[:status] == :new}
	@changed_entries = new_or_changed.select{|e| e[:status] == :changed}

	template = %q{
		<html>
		<head>
		<meta name="viewport" content="width=device-width">
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		</head>
		<body>
		<p>Aloha <%= @recipient_name %>,</p>
		<p>Here are the latest changes to Hawaiʻi Children's Action Network's <a href="https://covid19.hawaii-can.org/">COVID-19 Resources</a> guide:</p>
		<% if @new_entries.any? %>
			<p style="font-size:18px;line-height:18px;text-decoration:underline;font-weight:bold;">New entries</p>
			<% @new_entries.each do |entry| %>
				<p>
					<strong><%= entry[:name].to_s %></strong>
					<%= "<br/>#{entry[:description]}" if (!entry[:description].nil? && entry[:description] != "") %>
					<%= "<br/>Website: #{ entry[:url] }" if (!entry[:url].nil? && entry[:url] != "") %>
					<%= "<br/>Phone: #{ entry[:phone] }" if (!entry[:phone].nil? && entry[:phone] != "") %>
					<%= "<br/>Address: #{ address(entry) }" if address(entry) %>
				</p>
			<% end %>
		<% end %>
		<% if @changed_entries.any? %>
			<p style="font-size:18px;line-height:18px;text-decoration:underline;font-weight:bold;">Updated entries</p>
			<% @changed_entries.each do |entry| %>
				<p>
					<strong><%= entry[:name].to_s %></strong>
					<%= "<br/>#{entry[:description]}" if (!entry[:description].nil? && entry[:description] != "") %>
					<%= "<br/>Website: #{ entry[:url] }" if (!entry[:url].nil? && entry[:url] != "") %>
					<%= "<br/>Phone: #{ entry[:phone] }" if (!entry[:phone].nil? && entry[:phone] != "") %>
					<%= "<br/>Address: #{ address(entry) }" if address(entry) %>
				</p>
			<% end %>
		<% end %>
		<p>If you know of any other resources we should include, just reply to this email.</p>
		<p>Mahalo, <br> <a href="https://www.hawaii-can.org/">Hawaiʻi Children's Action Network</a></p>
		<br><br><p style='font-size:11px;line-height:11px;color:#444444;text-style:italic'>
			Sent by Hawaiʻi Children's Action Network, 850 Richards Street, Suite 201, Honolulu, HI 96816.
			<a href="https://www.hawaii-can.org/unsubscribe" style="color:#444444">Click here</a>
			to change your subscription preferences or unsubscribe.
		</p>
		</body></html>
	}

	return ERB.new(template, nil, "%<>").result
end

def send_email(email_content, recipient_address)
	time_now = Time.now.getlocal(ENV['TZ_OFFSET'])

	mail = Mail.new
	mail.from = Email.new(email: "info@hawaii-can.org", name: "Hawaiʻi Children's Action Network")
	mail.subject = "COVID-19 Resources update: #{time_now.strftime('%b. %-d, %Y')}"

	personalization = Personalization.new
	personalization.add_to(Email.new(email: recipient_address))
	mail.add_personalization(personalization)

	content = Content.new(type: 'text/html', value: email_content)
	mail.add_content(content)

	sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
	sg_response = sg.client.mail._('send').post(request_body: mail.to_json)
	puts sg_response.status_code
	puts sg_response.body
	puts sg_response.headers
end

run