<SecurityZoneLego name="${zone_name}" securityZoneId="${zone_id}" vLbId="${zone_id}-${route_domain}" vrfName="${vrf_name}" fwVSI="${fw_vsi}" zoneIndex="${route_domain}" subIntRouterBack="${sub_int_router_back}" visTechnic="fce-OBS-${zone_id}-${route_domain}-vip-forwarding">
		<Networks>
		  <Network name="fce-${zone_name}-${route_domain}-vlan-virt" type="virt">
		    <Vlan dvSwitch="" vlanId="${vlan_virt_id}" />
		    <Subnets>
		      <Subnet gateway="${virt_gateway}" subnetIp="${virt_subnet_ip}" subnetMask="${virt_subnet_mask}">
		         <IpAddresses>
		                <IpAddress ip="${virt_bigipha}" isReserved="true" label="bigIPHA" />
		                <IpAddress ip="${virt_bigip1}" isReserved="true" label="bigIP1" />
		                <IpAddress ip="${virt_bigip2}" isReserved="true" label="bigIP2" />
		                <IpAddress ip="${virt_gateway}" isReserved="true" label="VSYS" />
		     	 </IpAddresses>
				</Subnet>
		    </Subnets>
		  </Network>
		  <Network name="fce-${zone_name}-${route_domain}-vlan-data" type="data">
		  <Vlan dvSwitch="dvSwitch-FrontEnd" vlanId="${vlan_data_id}"/>
		    <Subnets>
		        <Subnet gateway="${data_bigipha}" subnetIp="${data_subnet_ip}" subnetMask="${data_subnet_mask}">
		         <IpAddresses>
		            <IpAddress ip="${data_bigip1}" isReserved="true" label="bigIP1" /> 
		            <IpAddress ip="${data_bigip2}" isReserved="true" label="bigIP2" />
		            <IpAddress ip="${data_bigipha}" isReserved="true" label="bigIPHA"/>
		 	 	</IpAddresses>
		      </Subnet>
		    </Subnets>
		  </Network>
		  <Network name="fce-${zone_name}-${route_domain}-vlan-priv" type="private">
		  <Vlan dvSwitch="dvSwitch-BackEnd" vlanId="${vlan_priv_id}"/>
		    <Subnets>
		        <Subnet gateway="${priv_asr_standby}" subnetIp="${priv_subnet_ip}" subnetMask="${priv_subnet_mask}">
		         <IpAddresses>
		            <IpAddress ip="${priv_asr_slave}" isReserved="true" label="ASR 2" /> 
		            <IpAddress ip="${priv_asr_master}" isReserved="true" label="ASR 1" />
		            <IpAddress ip="${priv_asr_standby}" isReserved="true" label="ASR HSRP"/>
		 	 	</IpAddresses>
		      </Subnet>
		    </Subnets>
		  </Network>
		</Networks>
  </SecurityZoneLego>