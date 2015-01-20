<?xml version="1.0" encoding="UTF-8"?>
<!-- Ce fichier est correct. Il permet d'importer 1 vsa, ATTENTION il faut rajouter le vrfname avec le routeur NEXUS-->
<ImportInfrastructure
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://127.0.0.1/workspace/SOURCES/plugins/orange-raas-FHDataModel/src/main/plugin/resources/config/vsa/virtualSystemArchitecture.xsd">
  <VSAs>
    <VSA vsaId="${vsaname}">
      <VSys clusterFwId="${fw_id}" name="${cust_id}" vRouter="${cust_id}-vr"/><!-- ME Side -->
      <UHPRouter clusterRouterId="${asr_id}" />
      <ExternalZones>
        <ExtIPVPN physicalPort="ethernet1/1" vlanName="ext_${vlan_me_side}_ipvpn" ipIntVsys="${ext_vsys_ip}">
          <Subnet subnetIp="${ext_subnet}" subnetMask="${ext_mask}" gateway="${ext_gateway}">
	          <IpAddresses>
	           <#assign addresses>${ext_reserved_address}</#assign>
	            <#list addresses?split(",") as ipValue>
	              <IpAddress ip="${ipValue}" isReserved="true"/>
				</#list>
	          </IpAddresses>
          </Subnet>
        </ExtIPVPN>
      </ExternalZones>
      <SecurityZones>
        <SecurityZone name="${vsaname}_VPN" securityZoneId="feipvpn" type="FrontendIPVPN" vLbId="vlb_075_feipvpn" vrfName="${vrf_back}" vrfFront="${vrf_front}">
          <Networks>
            <Network name="${prefix_fe}" type="data"><!-- VSI Customer side -->
              <Vlan dvSwitch="${vsm}" vlanId="${vlan_customer_zone_side}"/>
                  <Subnets>
                    <Subnet gateway="${fe_gateway}" subnetIp="${fe_subnet}" subnetMask="${fe_mask}">
                      <IpAddresses>
                        <IpAddress ip="${fe_gateway}" isReserved="true" label="ISG"/>
                      </IpAddresses>
                    </Subnet>
                  </Subnets>
                </Network>
                <Network name="${prefix_be}" type="private">
                  <Vlan dvSwitch="${vsm}" vlanId="${vlan_customer_zone_side_admin}"/>
                  <Subnets>
                    <Subnet gateway="${be_gateway}" subnetIp="${be_subnet}" subnetMask="${be_mask}">
                      <IpAddresses>
                        <IpAddress ip="${be_gateway}" isReserved="true" label="ASR"/>
                      </IpAddresses>
                    </Subnet>
                  </Subnets>
                </Network>
              </Networks>
            </SecurityZone>
          </SecurityZones>
        </VSA>
      </VSAs>
    </ImportInfrastructure>
