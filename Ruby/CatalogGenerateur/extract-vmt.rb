#!/usr/bin/ruby
require 'nokogiri'
require 'csv'

csv_prefix = "csv_logical_catalog_"
if ARGV.count < 1
  puts "I need at least 1 parameter:"
  puts "#{__FILE__} {cvs_prefix_name} <xml_filename>"
  exit
end

f = File.open(ARGV[0])
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
	:repupgrade	=> nil
 }

  c.xpath("./Information/Name").each do |nom|
	   vmt_ips[k].merge!({:commercialname 	=> "#{nom['commercialName']}"})
	   vmt_ips[k].merge!({:shortname      	=> "#{nom['shortName']}"})
  end
  
  c.xpath("./Information/Version").each do |version|
	   vmt_ips[k].merge!({:osfamily       	=> "#{version['OSFamily']}"})
	   vmt_ips[k].merge!({:version       	=> "#{version['version']}"})
	   vmt_ips[k].merge!({:type       		=> "#{version['type']}"})
	   vmt_ips[k].merge!({:language      	=> "#{version['language']}"})
	   vmt_ips[k].merge!({:architecture  	=> "#{version['architecture']}"})
	end
 
  c.xpath("./Information/Description").each do |desc|
	   vmt_ips[k].merge!({:description    	=> "#{desc['description']}"})
	end
	
  c.xpath("./Information/Upgrade").each do |upgrade|
	   vmt_ips[k].merge!({:isrelay       	=> "#{upgrade['isRelay']}"})
	   vmt_ips[k].merge!({:repupgrade       => "#{upgrade['mountPoint']}"})
	end	
	
	c.xpath("./Information/ApplicationType").each do |appType|
	   vmt_ips[k].merge!({:useapplicationtypeid       => "#{appType['useApplicationTypeId']}"})
	end	 
	
	c.xpath("./OSRequirement/RAM").each do |ramreq|
		minMo = ramreq['minMo']
	   vmt_ips[k].merge!({:minmo       		=> ramreq['minMo']})
	   vmt_ips[k].merge!({:maxmo       		=> "#{ramreq['maxMo']}"})
	end	   
	c.xpath("./OSRequirement/CPU").each do |cpureq|
	   vmt_ips[k].merge!({:minmhz       	=> "#{cpureq['minMhz']}"})
	end	
	
	c.xpath("./OSRequirement/vCPU").each do |vcpureq|
	   vmt_ips[k].merge!({:mincpu      	=> "#{vcpureq['min']}"})
	   vmt_ips[k].merge!({:maxcpu      	=> "#{vcpureq['max']}"})
	end		

	c.xpath("./Middlewares/Middleware").each do |mdw|
	   vmt_ips[k].merge!({:middlewareid  	=> "#{mdw['useCatalogElementId']}"})
	end	
	
					# <OSRequirement>
					# <RAM minMo="4096" maxMo="4096" unlimited="true"/>
					# <CPU minMhz="256" unlimited="true"/>
					# <vCPU min="1" max="1"/>
				# </OSRequirement>
				# <Network createVNic="false"/>
				# <Middlewares>
					# <Middleware useCatalogElementId="31"/>
				# </Middlewares>
	
end

#csv_vmt_ips = STDOUT
csv_vmt_ips = File.open("#{csv_prefix}vmt_ips.csv", 'w')
hash2csv(vmt_ips, [
      :catalog_element_id,
    :optional,
    :vmnaming,
    :hostnaming,
    :commercialname ,
	:shortname      ,
	:osfamily      ,
	:version      ,
	:type      ,
	:language      ,
	:architecture      ,
	:description      ,
	:useapplicationtypeid      ,
	:minmo      ,
	:maxmo      ,
	:minmhz      ,
	:mincpu ,
	:maxcpu ,
	:middlewareid,
	:isrelay,
	:repupgrade ],
         csv_vmt_ips)


		 