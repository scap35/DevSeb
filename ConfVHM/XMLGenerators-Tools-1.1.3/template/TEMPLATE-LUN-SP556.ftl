<?xml version="1.0" encoding="UTF-8"?>
<actions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../src/main/plugin/resources/config/lun/lunImport.xsd">
	<creations>
	   <#if cn1 != ""><lun canonicalName="${cn1?lower_case}" physicalCapacity="${rcapacity1}" storageType="${storageType}" storageClass="${storageClass}" storageUnit="${storageUnit}"/></#if>
	   <#if cn2 != ""><lun canonicalName="${cn2?lower_case}" physicalCapacity="${rcapacity2}" storageType="${storageType}" storageClass="${storageClass}" storageUnit="${storageUnit}"/></#if>
	   <#if cn3 != ""><lun canonicalName="${cn3?lower_case}" physicalCapacity="${rcapacity3}" storageType="${storageType}" storageClass="${storageClass}" storageUnit="${storageUnit}"/></#if>
	   <#if cn4 != ""><lun canonicalName="${cn4?lower_case}" physicalCapacity="${rcapacity4}" storageType="${storageType}" storageClass="${storageClass}" storageUnit="${storageUnit}"/></#if>
	</creations>
	<deletions>
	</deletions>
</actions>
