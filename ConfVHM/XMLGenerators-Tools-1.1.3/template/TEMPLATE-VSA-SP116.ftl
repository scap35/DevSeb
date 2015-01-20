<?xml version="1.0" encoding="utf-8"?>
<ImportInfrastructure xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <VSAs>
    <VSA vsaId="${vsa_name}" type="LEGO">
      <VSys clusterFwId="${cluster_fw_id}" name="${cust_id}" vRouter="${cust_id}-vr"/>
      <LoadBalancer clusterLbId="${cluster_lb_id}" />
      <#if !vhm_control_back??>
      <#assign vhm_control_back>true</#assign>
      </#if>
       <#if !vhm_control_front??>
      <#assign vhm_control_front>false</#assign>
      </#if>
      <UHPRouter clusterRouterId="${cluster_router_id}" ManageUHPBack="${vhm_control_back}" ManageUHPFront="${vhm_control_front}"/>
      <ExternalZones>
        <ExtIPVPN physicalPort="ethernet2/1" vlanName="ext_1_ipvpn">
            <Subnet>
              <IpAddresses>
                <IpAddress ip="213.56.208.19" isReserved="true" label="ME GTW" /> 
                <IpAddress ip="213.56.208.20" isReserved="true" label="VSYS" /> 
                <IpAddress ip="213.56.208.21" isReserved="true" label="SSL GTW" /> 
              </IpAddresses>
            </Subnet>
          </ExtIPVPN>
        <ExtInet physicalPort="ethernet1/1" />
        <TransAdm gatewaySsl="10.6.138.93" physicalPort="ethernet2/4" />
      </ExternalZones>
       <AdminNetworks><#if vhm_control_front??>
        <AdminNetwork name="CustAdmin" subnetAddress="${cust_admin}" subnetMask="${custadmin_netmask}" networkType="data" />
      </AdminNetworks></#if>
    </VSA>
  </VSAs>
</ImportInfrastructure>