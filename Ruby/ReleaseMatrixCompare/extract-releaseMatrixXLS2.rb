#!/usr/bin/ruby
# ------------------------------------------------------------------------------------
# Auteur : S. Caprais
# Date   : 26/06/2014
# Description :
# lire le fichier MatrixRelease
# ------------------------------------------------------------------------------------

require 'nokogiri'
require 'spreadsheet'
require 'csv2other'
require 'csv'

if ARGV.count < 1
  puts "I need at least 2 parameters:"
  puts "#{__FILE__} <matrixRelease> <xml_filename>"
  exit
end

f = File.open(ARGV[1])
doc = Nokogiri::XML(f)
f.close

def hash2csv(hash, header, out = STDOUT, csv_options = {:col_sep => ";"})
  out.puts CSV.generate_line(header, options = csv_options)
  hash.each do |k, v|
    line = []
    header.each do |r|
      line << v[r]
    end
    out.puts CSV.generate_line(line, options = csv_options)
  end
end

vmt_ips = {}

doc.xpath("//Collection/VMTemplate").each do |c|
  k = c['catalogElementId']
  vmt_ips[k] = {} unless vmt_ips.has_key? k
  
  vmt_ips[k] = {
    :catalog_element_id => k,
    :optional          => c['optional'],
    :vmnaming          => c['vmNaming'],
    :hostnaming       => c['hostNaming'],
    :commercialname       => nil,
	:shortname       => nil,
	:osfamily       => nil,
	:version       => nil,
	:type       => nil,
	:language       => nil,
	:architecture       => nil,
	:description       => nil,
	:useapplicationtypeid       => nil,
	:minmo       => nil,
	:maxmo       => nil,
	:minmhz       => nil,
	:mincpu       => nil,
	:maxcpu       => nil,
	:middlewareid       => nil,
	:isrelay	=> nil,
	:repupgrade	=> nil,
	:versionHCS => nil
 }

  c.xpath("./Information/Name").each do |nom|
	   vmt_ips[k].merge!({:commercialname 	=> "#{nom['commercialName']}"})
	   vmt_ips[k].merge!({:shortname      	=> "#{nom['shortName']}"})
	   #if (#{nom['shortName']} =~ /(.*)-HCS(.*)/)
	   my_match = /(.*)-HCS(.*)/.match(nom['shortName'])
	   vmt_ips[k].merge!({:versionHCS => my_match[2]})
  end
  
end

def catalogElementId  (vmts, nomVMT)
  vmts.each do |vmt|
	# decomposer le longname en shortname + version 
	my_match1 = /(.*)-(.*)/.match(nomVMT)
	my_match2 = /(.*)-HCS(.*)/.match(vmt[1][:shortname])
	
	unless (my_match1 == nil) || (my_match2 == nil)
	  shortn1 = my_match1[1]
	  version1 = my_match1[2]
	  shortn2 = my_match2[1]
	  version2 = my_match2[2]
		# puts "shortname :"
		# puts shortn1
		# puts "version:"
		# puts version1
		# puts "shortname :"
		# puts shortn2
		# puts "version:"
		# puts version2
		# puts "nom:"
		# puts vmt[1][:shortname] 
		if (shortn1 == shortn2) && (version1 == version2)
		  return vmt[1][:catalog_element_id]
		end
	end # unless  my_match
  end
  return "pas trouve"
end

book = Spreadsheet.open(ARGV[0]) 
ligne = 0
book.worksheet('Catalogue VHM').each do |row|
  ligne = ligne + 1
  if (ligne == 4)
    #puts row.join(',')
	entete = row
  else
    puts "#{row[17]},#{catalogElementId(vmt_ips,row[17])}"
	#puts "#{row[17]}"
  end
  #break if ligne == 6
end



		 