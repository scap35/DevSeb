#!/usr/bin/ruby
require 'nokogiri'
require 'csv'
# si un fichier de conf de zone est fourni en 3eme parametre, alors le tableau topo_vm contiendra l'information suivante : 
# Est ce que le vmt est déclaré dans la conf de zone ? si oui => (R) en suffixe au catalogElementId

if ARGV.count < 2
  puts "I need 2 parameters:"
  puts "#{__FILE__} <cvs_prefix_name> <xml_filename>"
  exit
end

csv_prefix 		= ARGV[0]
xml_filename 	= ARGV[1]
xml_zoneconf 	= ARGV[2]

  puts "csv_prefix: #{csv_prefix} ; xml_filename: #{xml_filename}; xml_zoneconf #{xml_zoneconf}"

unless File.exist? xml_filename
  puts "#{xml_filename} must exist"
  exit
end

if  File.exist? csv_prefix
  puts "cvs_prefix_name is not a file and must be provided"
  exit
end

list_license_os = {}
list_os = {}
list_license_mid = {}
list_mid = {}

f = File.open(xml_filename)
doc = Nokogiri::XML(f)
f.close

# lecture de la conf de zone 
# ----------------------------------------------------------------------
vmt_ips = {}
if ARGV.count > 2 and File.exist? xml_zoneconf
	f = File.open(xml_zoneconf)
	confZone = Nokogiri::XML(f)
	f.close	
	confZone.xpath("//CatalogImplementation/VMTemplate").each do |c|
		k = c['catalogElementId']
		vmt_ips[k] = {} unless vmt_ips.has_key? k
	end
else 
	puts 'conf de zone non fournie'
end

unless vmt_ips == {}
	puts vmt_ips
end
# ----------------------------------------------------------------------

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

middleware_collections = {}
virtual_system_collections = {}
vapp_collections = {}
topology_collections = {}

doc.xpath("//MiddlewareCollections/Collection").each do |c|
  collection_name = c['name']

  c.xpath("./Middleware").each do |e|
    k = e['catalogElementId']

    if middleware_collections.has_key? k
      puts "Middleware already exists: #{k}"
      next e
    end

    middleware_collections[k]= {
      :collection_name                => collection_name,
      :catalog_element_id             => e['catalogElementId'],
      :status                         => e['status'],
      :use_license_id                 => e['useLicenseId'],
      :required_available_space_in_go => e['requiredAvailableSpaceInGo'],
      :configurable_size              => e['configurableSize'],
    }

    s = e.xpath("./Information/Name").first
    middleware_collections[k].merge!({
      :commercial_name => s['commercialName'],
      :short_name      => s['shortName'],
    })
	
	s = e.xpath("./Information/Description").first
    middleware_collections[k].merge!({
      :description => s['description'],
    })
	
	s = e.xpath("./Information/Version").first
    middleware_collections[k].merge!({
      :version => s['version'], 
	  :type => s['type'], 
	  :language => s['language'], 
	  :architecture => s['architecture'], 
    })
	
	s = e.xpath("./OSRequirement/RAM").first
    middleware_collections[k].merge!({
      :ramMinMo => s['minMo'], 
    })
	
	s = e.xpath("./OSRequirement/CPU").first
    middleware_collections[k].merge!({
      :cpuMinMhz => s['minMhz'], 
    })
	
	s = e.xpath("./OSRequirement/vCPU").first
    middleware_collections[k].merge!({
      :vCPUmin => s['min'], 
    })
	
	s = e.xpath("./MiddlewareRepository").first
    middleware_collections[k].merge!({
      :repositoryId => s['repositoryId'], 
	  :path => s['path'], 
    })	
	
			
	
  end
end

doc.xpath("//VirtualSystemCollections/Collection").each do |c|
  collection_name = c['name']

  c.xpath("./VMTemplate").each do |e|
    k = e['catalogElementId']

    if virtual_system_collections.has_key? k
      puts "Template already exists: #{k}"
      next e
    end

    virtual_system_collections[k] = {
      :collection_name    => collection_name,
      :catalog_element_id => e['catalogElementId'],
      :status             => e['status'],
      :use_license_id     => e['useLicenseId'],
      :optional           => e['optional'],
      :backup             => e['backup'],
      :vm_naming          => e['vmNaming'],
    }

    s = e.xpath("./Information/Name").first
    virtual_system_collections[k].merge!({
      :commercial_name => s['commercialName'],
      :short_name      => s['shortName'],
    })

    s = e.xpath("./Information/Version").first
    virtual_system_collections[k].merge!({
      :os_family    => s['OSFamily'],
      :version      => s['version'],
      :type         => s['type'],
      :language     => s['language'],
      :architecture => s['architecture'],
    })

    s = e.xpath("./Information/Description").first
    virtual_system_collections[k].merge!({
      :description => s['description'],
    })

    s = e.xpath("./OSRequirement/RAM").first
    virtual_system_collections[k].merge!({
      :min_mo        => s['minMo'],
      :max_mo        => s['maxMo'],
      :ram_unlimited => s['unlimited'],
    })

    s = e.xpath("./OSRequirement/CPU").first
    virtual_system_collections[k].merge!({
      :min_mhz       => s['minMhz'],
      :cpu_unlimited => s['unlimited'],
    })

    s = e.xpath("./OSRequirement/vCPU").first
    virtual_system_collections[k].merge!({
      :vcpu_min => s['min'],
      :vcpu_max => s['max'],
    })

    s = e.xpath("./Middlewares")
    if s.count > 1
      virtual_system_collections[k].merge!({
        :use_catalog_element_id => "CheckNeeded",
      })
    elsif s.count == 1
      s = e.xpath("./Middlewares/Middleware").first
      virtual_system_collections[k].merge!({
        :use_catalog_element_id => s['useCatalogElementId'],
      })
    else
      virtual_system_collections[k].merge!({
        :use_catalog_element_id => "",
      })
    end
  end
end

doc.xpath("//VappCollections/Collection").each do |c|
  collection_name = c['name']

  c.xpath("./VApp").each do |e|
    k = e['vappId']

    if vapp_collections.has_key? k
      puts "Collection already exists: #{k}"
      next e
    end

    vapp_collections[k]= {
      :collection_name  => collection_name,
      :vapp_id          => e['vappId'],
      :name             => e['name'],
      :description      => e['description'],
      :topologies       => [],
      :virtual_machines => {},
    }

    e.xpath("./VappGroup").each do |va|
      va.xpath("./VirtualMachine").each do |vm|
        vmid  = vm['catalogElementId']
        order = va['orderStart']
        if vapp_collections[k][:virtual_machines].has_key? vmid
          puts "Duplicate vm in vapp_collections: #{e['name']} => #{vmid}"
        else
          vapp_collections[k][:virtual_machines][vmid] = order
        end
      end
    end
  end
end

doc.xpath("//TopologyCollections/Collection").each do |c|
  collection_name = c['name']

  c.xpath("./Topology").each do |e|
    k = e['name']

    if topology_collections.has_key? k
      puts "Topology already exists: #{k}"
      next e
    end

    topology_collections[k]= {
      :collection_name  => collection_name,
      :name             => e['name'],
      :version          => e['version'],
      :display_name     => e['displayName'],
      :description      => e['description'],
      :migration_target => e['migrationTargetTopologyName'],
      :vapps            => {}
    }

    e.xpath("./VApps/VApp").each do |v|
      vappid = v['catalogElementId']
      topology_collections[k][:vapps][vappid] = v['orderStart']
      if vapp_collections.has_key? vappid
        vapp_collections[vappid][:topologies] << k
      else
        puts "Vapp missing: #{vappid}"
      end
    end
  end
end

##csv_middleware_collections = STDOUT
csv_middleware_collections = File.open("#{csv_prefix}middleware_collections.csv", 'w')
hash2csv(middleware_collections, [
         :collection_name,
         :catalog_element_id,
         :status,
         :use_license_id,
         :required_available_space_in_go,
         :configurable_size,
         :commercial_name,
         :short_name,
		 :description,
		 :version,
		 :path,
		 :OSFamily,
		 :type,
		 :ramMinMo,
		 :CPUMinMhz,
		 :vCPUmin,
		 :repositoryId,
		 :language,
		 :architecture,
		 :installation
		 ],
         csv_middleware_collections)

#csv_virtual_system_collections = STDOUT
csv_virtual_system_collections = File.open("#{csv_prefix}virtual_system_collections.csv", 'w')
hash2csv(virtual_system_collections, [
		:collection_name,
		:catalog_element_id,
		:status,
		:use_license_id,
		:optional,
		:backup,
		:vm_naming,
		:commercial_name,
		:short_name,
		:os_family,
		:version,
		:type,
		:language,
		:architecture,
		:description,
		:min_mo,
		:max_mo,
		:ram_unlimited,
		:min_mhz,
		:cpu_unlimited,
		:vcpu_min,
		:vcpu_max,
		:use_catalog_element_id,
		 ],
         csv_virtual_system_collections)

#csv_vapp_collections = STDOUT
csv_vapp_collections = File.open("#{csv_prefix}vapp_collections.csv", 'w')
hash2csv(vapp_collections, [
         :collection_name,
         :vapp_id,
         :name,
         :description,
		 ],
         csv_vapp_collections)

#csv_topology_collections = STDOUT
csv_topology_collections = File.open("#{csv_prefix}topology_collections.csv", 'w')
hash2csv(topology_collections, [
         :collection_name,
         :name,
         :version,
         :display_name,
         :migration_target,
		 ],
         csv_topology_collections)

csv_vapp_topology_matrix = File.open("#{csv_prefix}matrix_vapp_topology.csv", 'w')
topologies = topology_collections.keys
csv_vapp_topology_matrix.puts "name;vapp;#{topologies.join ";"}"
vapp_collections.each do |k, v|
  line = []
  line << v[:name]
  line << k
  topologies.each do |c|
    if v[:topologies].include? c
      line << "X"
    else
      line << ""
    end
  end
  csv_vapp_topology_matrix.puts line.join ";"
end

csv_topology_vm_matrix = File.open("#{csv_prefix}matrix_topology_vm.csv", 'w')
vapps = vapp_collections.keys
vsystems = virtual_system_collections.keys
#puts vapp_collections
csv_topology_vm_matrix.puts ";#{vapps.map{ |v| vapp_collections[v][:name] }.join ";"}"
csv_topology_vm_matrix.puts "topology;#{vapps.join ";"}"
topology_collections.each.each do |k, v|
  line = []
  line << k
  #puts 'topo: ' + k
  vapps.each do |c|
    if v[:vapps].has_key? c
		# affiche les VMs de la vApp
		chaine =""
		vapp_collections[c][:virtual_machines].keys.each do |vmt|
			if chaine.length == 0
				chaine = "#{vmt}" 
			else
				chaine = chaine + "-" + "#{vmt}"
			end
			chaine = chaine + "(R)" if vmt_ips.has_key? vmt
		end
		#chaine = vapp_collections[c][:virtual_machines].keys.join("-")
      line << chaine
    else
      line << ""
    end
  end
  csv_topology_vm_matrix.puts line.join ";"
end

csv_topology_vapp_matrix = File.open("#{csv_prefix}matrix_topology_vapp.csv", 'w')
vapps = vapp_collections.keys
csv_topology_vapp_matrix.puts ";#{vapps.map{ |v| vapp_collections[v][:name] }.join ";"}"
csv_topology_vapp_matrix.puts "topology;#{vapps.join ";"}"
topology_collections.each.each do |k, v|
  line = []
  line << k
  vapps.each do |c|
    if v[:vapps].has_key? c
      line << "X"
    else
      line << ""
    end
  end
  csv_topology_vapp_matrix.puts line.join ";"
end

csv_vm_vapp_matrix = File.open("#{csv_prefix}matrix_vm_vapp.csv", 'w')
vsystems = virtual_system_collections.keys
csv_vm_vapp_matrix.puts ";;#{vsystems.map{ |v| virtual_system_collections[v][:vm_naming]}.join ';'}"
csv_vm_vapp_matrix.puts ";;#{vsystems.join ';'}"
vapp_collections.each do |k, v|
  line = []
  line << v[:description]
  line << k
  vsystems.each do |c|
    if v[:virtual_machines].has_key? c
      line << "X"
    else
      line << ""
    end
  end
  csv_vm_vapp_matrix.puts line.join ';'
end

exit
