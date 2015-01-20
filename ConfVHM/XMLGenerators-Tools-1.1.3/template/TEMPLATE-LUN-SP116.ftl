<?xml version="1.0" encoding="UTF-8"?>
<actions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../src/main/plugin/resources/config/lun/storageUnitsImport.xsd">
	<creations>
	<#if storageType == "LUN">
	<lun canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageType="${storageType}" storageClass="${storageClass}" storageUnit="${storageUnit}"/>
	<#elseif storageType == "SAN">
	<SAN canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageClass="${storageClass}" storageUnit="${storageUnit}"/>
	<#elseif storageType == "NAS">
	<NAS canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageClass="${storageClass}" storageUnit="${storageUnit}" dataStoreName="${dataStoreName}"/>
	<#elseif storageType == "NASDRP">
	<NASDRP canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageClass="${storageClass}" storageUnit="${storageUnit}" dataStoreName="${dataStoreName}"/>
	</#if>
	</creations>
	<deletions>
	</deletions>
</actions>