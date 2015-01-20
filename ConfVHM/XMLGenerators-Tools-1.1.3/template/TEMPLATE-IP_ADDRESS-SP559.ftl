<CatalogImplementation>
<#list CatalogImplementations as template>
	<VMTemplate catalogElementId="${template.catalogElementId}">
		<Eth number="0" address="${template.eth0_address}" networkType="${template.eth0_type}"/>
	<#if (template.eth1_type != "")>
		<Eth number="1" address="${template.eth1_address}" networkType="${template.eth1_type}"/>
	</#if>
	</VMTemplate>
</#list>	
</CatalogImplementation>