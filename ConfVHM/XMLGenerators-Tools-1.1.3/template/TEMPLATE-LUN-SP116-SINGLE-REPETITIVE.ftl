<#if storageType == "LUN">
<lun canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageType="${storageType}" storageClass="${storageClass}" storageUnit="${storageUnit}"/>
<#elseif storageType == "SAN">
<SAN canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageClass="${storageClass}" storageUnit="${storageUnit}"/>
<#elseif storageType == "NAS">
<NAS canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageClass="${storageClass}" storageUnit="${storageUnit}" dataStoreName="${dataStoreName}"/>
<#elseif storageType == "NASDRP">
<NASDRP canonicalName="naa.${wwn}" physicalCapacity="${capacity}" storageClass="${storageClass}" storageUnit="${storageUnit}" dataStoreName="${dataStoreName}"/>
</#if>