<?xml version="1.0" encoding="UTF-8"?>
<LogicalCatalog xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="logicalCatalog.xsd">
	<Licenses>
		<#list Licences as licence>
			<License licenseId="${licence.licenceId?left_pad(5, "0")}" name="${licence.name}" type="${licence.type}" isBillable="false" isManaged="${licence.isManaged}" billingCode="VIERGE"/>
		</#list>
	</Licenses>
	                                <!-- A P P L I C A T I O N  T Y P E S -->
	<ApplicationTypes>
		<#list ApplicationTypes as applicationType>
			<ApplicationType applicationTypeId="${applicationType.applicationTypeId}" name="${applicationType.name}" vmWareToolsAccess="${applicationType.vmWareToolsAccess}"/>
		</#list>		
	</ApplicationTypes>
                                <!-- M I D D L E W A R E -->
	<MiddlewareRepositories>
		<#list MiddlewareRepositories as middlewareRepository>
			<MiddlewareRepository repositoryId="${middlewareRepository.repositoryId}">
				<LocalRepository repositoryDestroyAfterCloneVM="${middlewareRepository.repositoryDestroyAfterCloneVM}" vmdk="${middlewareRepository.vmdk}" mountPoint="${middlewareRepository.mountPoint}"/>
			</MiddlewareRepository>	
		</#list>
	</MiddlewareRepositories>
	<MiddlewareCollections>
		<#list MiddlewareCollections?sort_by("collectionName") as middlewareCollection>
			<#-- vérifier si l'on doit créer un nouvel objet collection -->
			<#if currentMiddlewareCollectionName ??>
				<#if currentMiddlewareCollectionName!= middlewareCollection.collectionName>
					</Collection>
					<Collection name="${middlewareCollection.collectionName}">
					<#assign currentMiddlewareCollectionName = middlewareCollection.collectionName>
				</#if>
				<#-- sinon, on reste dans la meme collection -->
			<#else>
					<Collection name="${middlewareCollection.collectionName}">
					<#assign currentMiddlewareCollectionName = middlewareCollection.collectionName>
			</#if>
					<#-- ajouter le middleware courant-->
						<Middleware catalogElementId="${middlewareCollection.catalogElementId}" status="${middlewareCollection.status}" useLicenseId="${middlewareCollection.licenseId?left_pad(5, "0")}" requiredAvailableSpaceInGo="${middlewareCollection.requiredAvailableSpaceInGo}" configurableSize="${middlewareCollection.configurableSize}">
							<Information>
								<Name commercialName="${middlewareCollection.commercialName}" shortName="${middlewareCollection.shortName}"/>
								<Version OSFamily="${middlewareCollection.OSFamily}" version="${middlewareCollection.version}" type="${middlewareCollection.type}" language="${middlewareCollection.language}" architecture="${middlewareCollection.architecture}"/>
								<Description description="${middlewareCollection.description}"/>
							</Information>
							<OSRequirement>
								<RAM minMo="${middlewareCollection.ramMinMo}"/>
								<CPU minMhz="${middlewareCollection.CPUminMhz}"/>
								<vCPU min="${middlewareCollection.vCPUmin}"/>
							</OSRequirement>
							<MiddlewareRepository repositoryId="${middlewareCollection.repositoryId}" path="${middlewareCollection.path}"/>
							<Installation>
								<Commands>
									${middlewareCollection.installation}
								</Commands>
							</Installation>
						</Middleware>
		</#list>
		<#-- fermer la dernière collection -->
					</Collection>
	</MiddlewareCollections>
                              <!-- C O L L E C T I O N / V M - T E M P L A T E S -->
                                          <!-- V M S - I T D -->
	<VirtualSystemCollections>
		<!-- un VirtualSystemCollection contient des collections d'objets de types :
			- VMTemplate dont le type est optionnel; il provient alors de la liste VMTemplateType
			- VAPPTemplate.
			- Topology tirant partie des VMTemplates et VAPPTemplate.
		-->
		<#list VirtualSystemCollections?sort_by("collectionName") as virtualSystemCollection>		
			<#-- sert à trouver les id des template des vapps -->
			<#assign shortNameId=(shortNameId!{}) +  {virtualSystemCollection.shortName:virtualSystemCollection} >
			
			<#if currentVirtualSystemCollectionName ??>
				<#if currentVirtualSystemCollectionName!= virtualSystemCollection.collectionName>
					</Collection>
					<Collection name="${virtualSystemCollection.collectionName}">
					<#assign currentVirtualSystemCollectionName = virtualSystemCollection.collectionName>
				</#if>
				<#-- sinon, on reste dans la meme collection -->
			<#else>
					<Collection name="${virtualSystemCollection.collectionName}">
					<#assign currentVirtualSystemCollectionName = virtualSystemCollection.collectionName>
			</#if>
			<#-- sinon, on reste dans la meme collection -->
						<VMTemplate catalogElementId="${virtualSystemCollection.catalogElementId}" status="${virtualSystemCollection.status}" useLicenseId="${virtualSystemCollection.useLicenseId?left_pad(5, "0")}" optional="${virtualSystemCollection.optional}" backup="${virtualSystemCollection.backup}" vmNaming="${virtualSystemCollection.vmNaming}" hostNaming="${virtualSystemCollection.hostNaming}">
							<Information>
								<Name commercialName="${virtualSystemCollection.commercialName}" shortName="${virtualSystemCollection.shortName}"/>
								<Version OSFamily="${virtualSystemCollection.OSFamily}" version="${virtualSystemCollection.version}" type="${virtualSystemCollection.type}" language="${virtualSystemCollection.language}" architecture="${virtualSystemCollection.architecture}"/>
								<Description description="${virtualSystemCollection.description}"/>
							<#if virtualSystemCollection.isRelay?lower_case=="true">
								<Upgrade isRelay="true" mountPoint="${virtualSystemCollection.mountPoint}"/>
							</#if>
								<ApplicationType useApplicationTypeId="${virtualSystemCollection.useApplicationTypeId}"
								<#if virtualSystemCollection.role!="">
									role="${virtualSystemCollection.role}"
								</#if>
								/>
							</Information>
							<OSRequirement>
								<#if virtualSystemCollection.unlimitedRAM?has_content>
									<#assign unlimitedRAM=virtualSystemCollection.unlimitedRAM>
								<#else>
									<#assign unlimitedRAM="false">
								</#if>
								<#if virtualSystemCollection.unlimitedCPU?has_content>
									<#assign unlimitedCPU=virtualSystemCollection.unlimitedCPU>
								<#else>
									<#assign unlimitedCPU="false">
								</#if>
								<RAM minMo="${virtualSystemCollection.minMo}" maxMo="${virtualSystemCollection.maxMo}" unlimited="${unlimitedRAM}"/>
								<CPU minMhz="${virtualSystemCollection.minMhz}" unlimited="${unlimitedCPU}"/>
								<vCPU min="${virtualSystemCollection.minVCpu}" max="${virtualSystemCollection.maxVCpu}"/>
							</OSRequirement>
							<Network createVNic="false"/>
							<#if virtualSystemCollection.middlewareId != "" >
								<Middlewares>
									<Middleware useCatalogElementId="${virtualSystemCollection.middlewareId}"/>
								</Middlewares>
							</#if>
						</VMTemplate>
		</#list>
					</Collection>
	</VirtualSystemCollections>
                              <!--  -->
                              <!-- V A P P - C O L L E C T I O N S -->
                              <!--  -->
	<VappCollections>
		<#assign vappFound = []> <#-- gérer les doublons dans les vappId-->
		<#assign topologyCollectionHash = {}> <#-- faire une nouvelle map dans laquelle on range les topologies par collection / version / nb devices -->
		<#list TopologyCollections?sort_by("vappCollectionName", "vappId") as vappCollection>
			<#-- récupérer la topology collection en hash, si elle existe -->
			<#assign collectionHash = topologyCollectionHash[vappCollection.collectionName]!{}>
			<#-- récupérer la version en hash, si elle existe -->
			<#assign versionHash = collectionHash[vappCollection.version]!{}>
			<#-- récupérer le nombre de devices  en hash, s'il existe -->
			<#assign nbDevicesHash = versionHash[vappCollection.numberOfDevices]!{"displayName": vappCollection.displayName, "description":vappCollection.description, "migrationTargetTopologyName":vappCollection.migrationTargetTopologyName, "vapps":[] }>
			<#-- récupérer la liste des vapp, si elle existe et lui ajouter la vapp en cours -->
			<#assign vappList = (nbDevicesHash.vapps![]) + [{"vappId":vappCollection.vappId, "orderStart":vappCollection.vappOrderStart, "vappDescription":vappCollection.vappDescription}] >
			
			
			<#-- créer le XML de la vapp -->
			<#if currentVappCollectionName ??>
				<#if currentVappCollectionName!= vappCollection.vappCollectionName>
					</Collection>
					<Collection name="${vappCollection.vappCollectionName}">
					<#assign currentVappCollectionName = vappCollection.vappCollectionName>
				</#if>
				<#-- sinon, on reste dans la meme collection -->
			<#else>
				<Collection name="${vappCollection.vappCollectionName}">
				<#assign currentVappCollectionName = vappCollection.vappCollectionName>
			</#if>
			<#-- sinon, on reste dans la meme collection -->
			<#-- attention aux doublons: ne pas créer deux fois la meme vapp (vappId)-->
			<#if !(vappFound?seq_contains(vappCollection.vappId)) >
					<VApp vappId="${vappCollection.vappId}" name="${vappCollection.vappName}" description="${vappCollection.vappDescription}">
			</#if>
			<#assign vappOrder = 1>
			<#if vappCollection.template?is_string>
				<#assign vappCollectionTemplates = [vappCollection.template]>
			<#else>
				<#assign vappCollectionTemplates = vappCollection.template>
			</#if>
			<#list vappCollectionTemplates as templateName>
				<#if !(vappFound?seq_contains(vappCollection.vappId)) >
					<#if vappCollection.sameVappGroup == "false" || (vappCollection.sameVappGroup == "true" && vappOrder == 1)>
						<#if vappCollection.sameVappGroup == "true">
						<!-- Peuvent être demarrees en parallele -->
						</#if>
						<VappGroup orderStart="${vappOrder}">							
					</#if>
				</#if>
				<#-- on veut trouver l'id du template dont on a le nom -->
				<#if shortNameId[templateName] ??>
					<#assign vappOrder = vappOrder  + 1>
					<#assign template = shortNameId[templateName]>
						<#if !(vappFound?seq_contains(vappCollection.vappId)) >
								<!-- ${template.vmNaming} : ${template.description} -->
								<VirtualMachine catalogElementId="${template.catalogElementId}"/>
						</#if>		
						<#-- mettre à jour nbDeviceHash avec la liste des VMs pour les règles-->
						<#if template.type == "CUEAC01">
							<#assign nbDevicesHash = nbDevicesHash  + {"CUEAC01" : ((nbDevicesHash.CUEAC01![]) + [template])}>
						</#if>
						<#if template.useApplicationTypeId == "ADCNS">
							<#assign nbDevicesHash = nbDevicesHash  + {"ADCNS" : ((nbDevicesHash.ADCNS![]) + [template])}>									
						</#if>
						<#if template.useApplicationTypeId == "UCCX">
							<#assign nbDevicesHash = nbDevicesHash  + {"UCCX" : ((nbDevicesHash.UCCX![]) + [template])}>
						</#if>
						<#if template.useApplicationTypeId == "CUPS">
							<#assign nbDevicesHash = nbDevicesHash  + {"CUPS" : ((nbDevicesHash.CUPS![]) + [template])}>
						</#if>
						<#if template.useApplicationTypeId == "Unity">
							<#assign nbDevicesHash = nbDevicesHash  + {"Unity" : ((nbDevicesHash.Unity![]) + [template])}>
						</#if>
						<#if template.useApplicationTypeId == "CUCM" && template.role == "P">
							<#assign nbDevicesHash = nbDevicesHash  + {"CUCMP" : ((nbDevicesHash.CUCMP![]) + [template])}>
						</#if>
						<#if template.useApplicationTypeId == "CUCM" && template.role == "S">
							<#assign nbDevicesHash = nbDevicesHash  + {"CUCMS" : ((nbDevicesHash.CUCMS![]) + [template])}>
						</#if>
						<#if template.OSFamily?upper_case?contains("WINDOWS")>
							<#assign nbDevicesHash = nbDevicesHash  + {"WINDOWS" : ((nbDevicesHash.WINDOWS![]) + [template])}>
						<#else>
							<#assign nbDevicesHash = nbDevicesHash  + {"LINUX" : ((nbDevicesHash.LINUX![]) + [template])}>
						</#if>
				<#else>
								***********ATTENTION: Le template ${templateName} est absent de la liste des templates*******************
				</#if>
				<#if !(vappFound?seq_contains(vappCollection.vappId)) &&  vappCollection.sameVappGroup == "false" >
						</VappGroup>
				</#if>
			</#list>	
			<#if !(vappFound?seq_contains(vappCollection.vappId)) && vappCollection.sameVappGroup ==  "true" >
						</VappGroup>
			</#if>
			<#if !(vappFound?seq_contains(vappCollection.vappId)) >
					</VApp>
			</#if>
			<#assign vappFound = (vappFound![]) +  [vappCollection.vappId]>							

			<#-- mettre à jour les infos de la topologie -->
			<#assign nbDevicesHash = nbDevicesHash  + {"vapps" : vappList}>
			<#assign versionHash = versionHash  + {vappCollection.numberOfDevices:nbDevicesHash}>
			<#assign collectionHash = collectionHash  + {vappCollection.version:versionHash}>
			<#assign topologyCollectionHash = topologyCollectionHash  + {vappCollection.collectionName:collectionHash}>			
		</#list>
			</Collection>
	</VappCollections>
                             <!--  -->
                             <!-- T O P O L O G Y - C O L L E C T I O N S  -->
                             <!--  -->
	<TopologyCollections>
		<#-- parcourir les clés de topologyCollectionHash -->
		<#list topologyCollectionHash?keys as topologyCollectionName>
			<#if topologyCollectionName != "">
				<#assign collectionHash = topologyCollectionHash[topologyCollectionName]>
				<Collection name="${topologyCollectionName}">
					<#-- parcourir les versions de la collection -->
					<#list collectionHash?keys as version>
						<#assign versionHash = collectionHash[version]>
						<#-- parcourir les nb devices de la collection -->
						<!--  T O P O L O G Y -->
						<!-- ${version} -->
						<#list versionHash?keys as nbDevices>
							<#-- ignorer les devices "all"-->
							<#if nbDevices != "all" >
								<#assign nbDevicesHash = versionHash[nbDevices]>
								<#-- là on crée la topologie -->
								<!-- ${nbDevices} -->
								<Topology name="UCaaS Cisco (${nbDevices}) ${version}" version="${version}" displayName="${nbDevicesHash.displayName!("Topologie UCaaS Cisco ("+nbDevices+") "+version)}" description="${nbDevicesHash.description!("Topologie UCaaS Cisco ("+nbDevices+") "+version)}" migrationTargetTopologyName="${nbDevicesHash.migrationTargetTopologyName}">
									<VApps>
										<#-- liste ses vapps -->
									<#list nbDevicesHash.vapps as vapp>
											<!-- ${vapp.vappDescription} -->
											<VApp catalogElementId="${vapp.vappId}" orderStart="${vapp.orderStart}"/>
									</#list>
									<#-- ajouter les vapp de  all -->
									<#if versionHash.all??>
										<#list versionHash.all.vapps as vapp>
												<!-- ${vapp.vappDescription} -->
											<VApp catalogElementId="${vapp.vappId}" orderStart="${vapp.orderStart}"/>
										</#list>
									</#if>
									</VApps>
									<Rules>
										<#if (((nbDevicesHash.WINDOWS![] + (versionHash.all!).WINDOWS![])?size) > 0)>
											<!--  R U L E S -->
											<!-- C O L L O C A L I S A T I O N -->
											<!-- regles de collocalisation des VMs Windows sur les memes blades, separees des blades UC/Cisco -->
											<Rule type="Collocalisation_VM_Host" name="vmWindowsGroup">
												<#list (nbDevicesHash.WINDOWS![] + (versionHash.all!).WINDOWS![]) as template>
													<!-- ${template.vmNaming} : ${template.description} -->
													<VirtualMachine catalogElementId="${template.catalogElementId}"/>
												</#list>
											</Rule>
										</#if>
								
										<#if ((((nbDevicesHash.LINUX![]) + ((versionHash.all!).LINUX![]))?size) > 0)>
											<!-- R U L E S -->
											<!-- C O L L O C A L I S A T I O N -->
											<!-- regles de collocalisation des VMs UC sur les memes blades, separees des blades Windows -->
											<Rule type="Collocalisation_VM_Host" name="vmUCGroup">
												<#list ((nbDevicesHash.LINUX![]) + ((versionHash.all!).LINUX![])) as template>
													<!-- ${template.vmNaming} : ${template.description} -->
													<VirtualMachine catalogElementId="${template.catalogElementId}"/>
												</#list>
											</Rule>
										</#if>
								
										<#if (((nbDevicesHash.CUEAC01![] + (versionHash.all!).CUEAC01![])?size) > 0)>
											<!-- R U L E S -->
											<!-- E X C L U S I O N    D E    V M s -->
											<!-- regles d'exclusion metier : CUEAC01 : soit express soit standard -->
											<Rule type="Exclusion_VM" name="RULE_CUEAC01_${r"${CLIENTACCOUNTNAME}"}">
												<#list (nbDevicesHash.CUEAC01![] + (versionHash.all!).CUEAC01![]) as template>
													<!-- ${template.vmNaming} : ${template.description} -->
													<VirtualMachine catalogElementId="${template.catalogElementId}"/>
												</#list>
											</Rule>
										</#if>
								
										<#if (((nbDevicesHash.UCCX![] + (versionHash.all!).UCCX![])?size) > 0)>
										<!-- R U L E S -->
										<!-- E X C L U S I O N    D E    V M s -->
										<!-- regles d'exclusion metier : UCCX100 et 300 incompatibles -->
										<Rule type="Exclusion_VM" name="RULE_UCCX100300_${r"${CLIENTACCOUNTNAME}"}">
											<#list (nbDevicesHash.UCCX![] + (versionHash.all!).UCCX![]) as template>
												<!-- ${template.vmNaming} : ${template.description} -->
												<VirtualMachine catalogElementId="${template.catalogElementId}"/>
											</#list>
										</Rule>
										</#if>
								
										<#if (((nbDevicesHash.ADCNS![] + (versionHash.all!).ADCNS![])?size) > 0)>
											<!-- R U L E S -->
											<!-- E X C L U S I O N    D E    V M s    S U R    E S X -->
											<!-- regles d'anti-affinite de virtualisation (DRS): AD1 & AD2 sur 2 hotes differents -->
											<Rule type="Exclusion_VM_ESX" name="RULE_ADs_${r"${CLIENTACCOUNTNAME}"}">
												<#list (nbDevicesHash.ADCNS![] + (versionHash.all!).ADCNS![]) as template>
													<!-- ${template.vmNaming} : ${template.description} -->
													<VirtualMachine catalogElementId="${template.catalogElementId}"/>
												</#list>
											</Rule>
										</#if>

										<#assign taille = ((nbDevices!)?word_list)[0]>
										<!-- R U L E S -->
										<!-- E X C L U S I O N    D E    V M s    S U R    E S X -->
										<#-- ici il faut juste la taille !!! -->
										<#if ((nbDevicesHash.CUCMP![] + (versionHash.all!).CUCMP![])?size == 1) && ((nbDevicesHash.CUCMS![] + (versionHash.all!).CUCMS![])?size == 1) >
											<!-- regles d'anti-affinite de virtualisation (DRS): Publisher P01 & Subscriber S01 sur 2 hotes differents -->
											<Rule type="Exclusion_VM_ESX" name="RULE_UC${taille}_${r"${CLIENTACCOUNTNAME}"}">
												<!-- ${nbDevicesHash.CUCMP[0].vmNaming} : ${template.description} -->
												<VirtualMachine catalogElementId="${nbDevicesHash.CUCMP[0].catalogElementId}"/>
												<!-- ${nbDevicesHash.CUCMS[0].vmNaming} : ${template.description} -->
												<VirtualMachine catalogElementId="${nbDevicesHash.CUCMS[0].catalogElementId}"/>
											</Rule>
										<#else>
											<#--lister les subscribers 2 par 2, ordre croissant du numéro -->
											<#assign first=true>
											<#assign cucmTemplates = ((nbDevicesHash.CUCMS![] + (versionHash.all!).CUCMS![]))>
											<#list cucmTemplates  as template>
												<#if first>
													<#assign first=false>
													<#assign nextTemplate=cucmTemplates[template_index + 1]>
													<#assign subscriber1=template.vmNaming?substring((template.vmNaming?last_index_of("S")))>
													<#assign subscriber2=nextTemplate.vmNaming?substring((nextTemplate.vmNaming?last_index_of("S")))>
													<!-- regles d'anti-affinite de virtualisation (DRS): Subscriber ${subscriber1} & Subscriber ${subscriber2} sur 2 hotes differents -->
													<Rule type="Exclusion_VM_ESX" name="RULE_UC${taille}_${subscriber1}${subscriber2}_${r"${CLIENTACCOUNTNAME}"}">
														<!-- ${template.vmNaming} : ${template.description} -->
														<VirtualMachine catalogElementId="${template.catalogElementId}"/>
															<#else>
																<#assign first=true>
														<!-- ${template.vmNaming} : ${template.description}  -->
														<VirtualMachine catalogElementId="${template.catalogElementId}"/>
													</Rule>
												</#if>
											</#list>
										</#if>
								
										<#assign allCups=((nbDevicesHash.CUPS![]) + (versionHash.all!).CUPS![])>
										<#if ((allCups?size) >= 2) >
											<#-- s'il y a des CUPS, si au monis 2 cups on a plusieurs règles : cups 1 & 2, 1& 3 -->
											<#list allCups  as cups>
												<#if (cups_index > 0)>
													<!-- regles d'anti-affinite de virtualisation (DRS): CUPS 1 & ${cups_index + 1} sur 2 hotes differents -->
													<Rule type="Exclusion_VM_ESX" name="RULE_UC${taille}_UCPS1${cups_index + 1}_${r"${CLIENTACCOUNTNAME}"}">
														<!-- ${(allCups[0]).vmNaming} : ${allCups[0].description} -->
														<VirtualMachine catalogElementId="${(allCups[0]).catalogElementId}"/>
														<!-- ${cups.vmNaming} : ${cups.description}  -->
														<VirtualMachine catalogElementId="${cups.catalogElementId}"/>
													</Rule>
												</#if>
											</#list>
										</#if>
										
										<#assign allUnity = (nbDevicesHash.Unity![] + (versionHash.all!).Unity![])>
										<#if ((allUnity?size) > 1) >
											<#-- s'il y a au moins 2 Unity --->
											<!-- regles d'anti-affinite de virtualisation (DRS): Unity CNX  sur 2 hotes differents -->
											<#assign first=true>
											<#list allUnity  as unity>
												<#if (unity_index > 0)>
													<!-- regles d'anti-affinite de virtualisation (DRS): Unity CNX 1 & ${unity_index + 1} sur 2 hotes differents -->
													<Rule type="Exclusion_VM_ESX" name="RULE_UC${taille}_CNX1${unity_index + 1}_${r"${CLIENTACCOUNTNAME}"}">
														<!-- ${allUnity[0].vmNaming} : ${allUnity[0].description}  -->
														<VirtualMachine catalogElementId="${allUnity[0].catalogElementId}"/>
														<!-- ${unity.vmNaming} : ${unity.description}  -->
														<VirtualMachine catalogElementId="${unity.catalogElementId}"/>
													</Rule>
												</#if>
											</#list>
										</#if>
									</Rules>
								</Topology>
							</#if>		
						</#list>
					</#list>	
				</Collection>
			</#if>
		</#list>
	</TopologyCollections>
</LogicalCatalog>
