#!/usr/bin/ruby
require 'nokogiri'
require 'csv'

csv_prefix = "csv_logical_catalog_"

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

doc.xpath("//CatalogImplementation/VMTemplate").each do |c|
  k = c['catalogElementId']

  vmt_ips[k] = {} unless vmt_ips.has_key? k

  vmt_ips[k] = {
    :catalog_element_id => k,
    :eth0_type          => nil,
    :eth1_type          => nil,
    :eth0_address       => nil,
    :eth1_address       => nil
  }

  c.xpath("./Eth").each do |e|
    id = e['number']

    vmt_ips[k].merge!({
        "eth#{id}_type".to_sym    => "#{e['networkType']}",
        "eth#{id}_address".to_sym => "#{e['address']}"
    })
  end
end

#csv_vmt_ips = STDOUT
csv_vmt_ips = File.open("#{csv_prefix}vmt_ips.csv", 'w')
hash2csv(vmt_ips, [
      :catalog_element_id,
      :eth0_type,
      :eth0_address,
      :eth1_type,
      :eth1_address
		 ],
         csv_vmt_ips)

