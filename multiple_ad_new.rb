#! /usr/bin/env ruby
# encoding: utf-8

require 'open-uri'
require 'uri'
require 'cgi'
require 'pp'

require 'rubygems'
require 'nokogiri'

DOMAIN_URL = 'http://www.moyareklama.ru/'

def find_last_page_index(url)

  doc = Nokogiri::HTML(open(url, 'Cookie' => 'city=3'))

  nodeset = doc.css('.page_m')[-2]
   
  unless nodeset.nil?
    page_url, _, page_index = _absolutize_url(
      nodeset['href']).rpartition('/')
  end

end

# Parse a page into an array of groups URLs.
def describe_groups(job_section_url)

  # looking_for_a_job_string = '%D0%98%D1%89%D1%83+%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D1%83'
  doc = Nokogiri::HTML(open(job_section_url, 'Cookie' => 'city=3'))

  doc.css('.group_title')[0..-2].map { |a| _absolutize_url(a['href']) }

end

# Parse single_ad_new.php?id=<ID> into array.
def describe_ad(ad_url)

  @ad_page = open(ad_url, 'Cookie' => 'city=3')
  @ad_doc = Nokogiri::HTML(@ad_page)
  @ad_hash = Hash.new
  @ad_id = URI(ad_url).query.split('=')[1]

  # .pv1_title
  @ad_title = @ad_doc.css('.title').text
  @amount = @ad_doc.css('.amount').text.strip
  
  # .pv1_block
  @_CONDITION_NODE = @ad_doc.css('.pv1_subtitle + .pv1_block').first
  @earning_system = @_CONDITION_NODE.css('.pv1_vacancy_line')[0].text.split(':')[1].strip
  @job_shedule = @_CONDITION_NODE.css('.pv1_vacancy_line')[1].text.split(':')[1].strip
  if not @_CONDITION_NODE.css('.pv1_vacancy_line')[2].nil?
    @job_description = @_CONDITION_NODE.css('.pv1_vacancy_line')[2].text.strip
  end
  
  if @ad_doc.css('.pv1_subtitle')[1].text.include?('Требования к кандидату')

    # .pv1_block
    @_node = @ad_doc.css('.pv1_subtitle + .pv1_block')[1].css('.pv1_vacancy_line')
    @_node.each do |div|
      case div
      when div.text.include?('Образование')
        @education = div.text.split(':').strip
      when div.text.include?('Опыт работы')
        @experience = div.text.split(':').strip
      when div.text.include?('Водительское удостоверение') 
        @driving_licence = div.text.split(':').strip
      when div.text.include?('Иностранный язык')
        @foreign_language= div.text.split(':').strip
      end #case 
    end #each

    # .pv1_block
    if not @ad_doc.css('.pv1_subtitle + .pv1_block + .pv1_block').empty?
      @requirements = @ad_doc.css('.pv1_subtitle + .pv1_block + .pv1_block').text.strip
    end #if

  end #if

  # .pv1_block
  if @ad_doc.css('.pv1_subtitle')[-3].text.include?('Должностные обязанности')      
    @responsibilities = @ad_doc.css('.pv1_block')[-3].css('.pv1_vacancy_line').text.strip
  end #if
   
  # .pv1_block
  @_EMPLOYER_NODE = @ad_doc.css('.pv1_subtitle + .pv1_block')[-2].css('.pv1_vacancy_line')
  if not @_EMPLOYER_NODE.css('a').empty?
    @company_id = @_EMPLOYER_NODE.css('a').first['href'].split('id=')[1]
    @card_url = 'http://moyareklama.ru/card.php?company_id=' + @company_id
  end #if
  @company_name = @_EMPLOYER_NODE.css('.pv1_vacancy_line').text.strip
  if @_EMPLOYER_NODE.text.include?(',')
    @company_name = @_EMPLOYER_NODE.text.split(',')[0].strip
    @company_field = @_EMPLOYER_NODE.text.split(',')[1].strip
  end #if

  # .pv1_block
  @location = @ad_doc.css('.pv1_subtitle + .pv1_block')[-1].css('.pv1_vacancy_line').text.strip
  @phones = @ad_doc.css('.pv1_phones').text.strip
  @email = @ad_doc.css('.pv1_email').text.strip
  @address = @ad_doc.css('div > .pv1_address.pv1_address_vacancy').text.strip.split[0 .. -3].join(' ')
  @lat = @ad_doc.css('.pv1_geo_lat')[0]['value'] if not @ad_doc.css('.pv1_geo_lat').empty?
  @lng = @ad_doc.css('.pv1_geo_lng')[0]['value'] if not @ad_doc.css('.pv1_geo_lng').empty?
  
  # .pv1_date
  @category = @ad_doc.css('.pv1_date').inner_html.split('<')[0].split('»')[0].strip
  @subcategory = @ad_doc.css('.pv1_date').inner_html.split('<')[0].split('»')[1].strip
  @ad_age = @ad_doc.css('.pv1_date .pv1_date').text.strip
  
  #_debug(@company_field)

  ['ad_id',
    'ad_title',
    'amount',
    'earning_system',
    'job_shedule',
    'job_description',
    'education',
    'experience',
    'driving_licence',
    'foreign_language',
    'requirements',
    'responsibilities',
    'card_url',
    'company_id',
    'company_name',
    'company_field',
    'location',
    'phones',
    'email',
    'address',
    'lat',
    'lng',
    'category',
    'subcategory',
    'ad_age'
  ].each do |key|
    @ad_hash[key.to_sym] = instance_variable_get("@" + key)
  end #each

  @card_hash = describe_card(@card_url) if not @card_url.nil?
  @ad_hash.merge!(@card_hash)

  @ad_hash

end #describe_ad

def describe_card(card_url)
=begin
Parse card.php?id=<ID> into array.
=end
  # http://blog.noort.be/2011/02/12/nokogiri-scraping-with-cookies.html
  @card_page = open(card_url, 'Cookie' => 'city=3')
  @card_doc = Nokogiri::HTML(@card_page)
  @card_hash = Hash.new
  
  @company_id = URI(card_url).query.split('=')[1]
  @company_name = @card_doc.css('.company_name').text
  @company_site = @card_doc.css('.company_site > a').first['href']
  @company_character = @card_doc.css('.company_character').text
  @company_description = @card_doc.css('.company_description p').text
  @company_ads_quantity = @card_doc.css('.ads_name').length.to_s
  @company_office_name = @card_doc.css('#filial_name_view').text.strip
  @company_office_address = @card_doc.css('#filial_address_view').text.strip
  @company_way = ''
  @company_ymap_link = @card_doc.css('.ymaps-logo-link').text
  
  ['company_id',
    'company_name',
    'company_site',
    'company_character',
    'company_description',
    'company_ads_quantity',
    'company_office_name',
    'company_office_address',
    'company_way',
    'company_ymap_link'
  ].each do |key|
    @card_hash[key.to_sym] = instance_variable_get("@" + key)
  end #each

  @card_hash

end #describe_card

def _debug(var)
  puts "VAR         = " + var
  puts "VAR INSPECT = " + var.inspect
  puts "VAR CLASS   = " + var.class.to_s
  puts "VAR LENGTH  = " + var.length.to_s if var.respond_to?('length')
  puts "VAR METHODS = " + var.public_methods.join(' ')
  puts
end

def _absolutize_url(url)
  URI.join(
    DOMAIN_URL,
    CGI.escape(url).gsub('%2F', '/')
  ).to_s
end

if __FILE__ == $0
end
