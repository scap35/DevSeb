-- Source: http://shp.itn.ftgroup/sites/cloudfactory/VHM/Operations/Tools-UCaaS-SP-500/delete-vdc.sql
-- Auteur : Nicolas Ledez <nicolas.ledez@orange.com>
-- Version : 1.5
-- Mode d'emploi :
-- Remplacer dans le script la valeur de la variable @vdc_to_delete avec le nom du VDC a suprimer
-- Ou forcer les valeurs plus bas
-- Compatible SP556

declare @vdc_to_delete varchar(255)
SET @vdc_to_delete = 'NomDuVDCaSupprimer'

-- Declaration des variables de "travail"
declare @id_vdc varchar(255)
declare @id_clust varchar(255)
declare @id_cpu varchar(255)
declare @id_resource varchar(255)
declare @id_rootfolder varchar(255)
declare @id_ram varchar(255)
declare @id_ds varchar(255)
declare @id_vsys varchar(255)
declare @id_vsa varchar(255)

-- Extraction des differents ID pour tout nettoyer en une passe
SELECT @id_vdc = [id]
      ,@id_clust = [CLUSTER_FK]
      ,@id_cpu = [CPURESOURCES_FK]
      ,@id_resource = [RESOURCEPOOL_FK]
      ,@id_rootfolder = [ROOTVMFOLDER_FK]
      ,@id_ram = [RAMRESOURCES_FK]
FROM [dbo].[DRAAS_VirtualResourcesInfo]
WHERE [name] = @vdc_to_delete

SELECT @id_ds = [DATASTORE_FK]
FROM [dbo].[DRAAS_Storage]
WHERE [VDC_FK] = @id_vdc

SELECT @id_vsa = [id]
      ,@id_vsys = [VSYS_FK]
  FROM [dbo].[DRAAS_Vsa]
WHERE [VIRTUALRESOURCESINFO_FK] = @id_vdc

-- Si les informations ne sont plus presentes dans la table du VDC,
-- aller les chercher dans les tables des ressources
IF @id_cpu is NULL
BEGIN
    SELECT @id_cpu = [id]
	FROM [dbo].[DRAAS_CpuResources]
	WHERE [VDC_FK] = @id_vdc
END

IF @id_ram is NULL
BEGIN
 SELECT @id_ram = [id]
  FROM [dbo].[DRAAS_RamResources]
  WHERE [VDC_FK] = @id_vdc
END

-- Permet de forcer les identifiants
-- SET @id_vdc = ''
-- SET @id_clust = ''
-- SET @id_cpu = ''
-- SET @id_resource = ''
-- SET @id_rootfolder = ''
-- SET @id_ram = ''
-- SET @id_ds = ''
-- SET @id_vsys = ''
-- SET @id_vsa = ''

-- Afficher la liste des identifiants
-- Les if NULL permetent de palier au fait que si la variable est NULL,
-- le print n'affiche rien du tout
print 'VDC Name: ' + @vdc_to_delete
print 'All ressources ID:'

IF @id_vdc is NULL
BEGIN
	print 'VDC: '
END
ELSE
BEGIN
	print 'VDC: ' + @id_vdc
END

IF @id_clust is NULL
BEGIN
	print 'Cluster: '
END
ELSE
BEGIN
	print 'Cluster: ' + @id_clust
END

IF @id_cpu is NULL
BEGIN
	print 'Cpu: '
END
ELSE
BEGIN
	print 'Cpu: ' + @id_cpu
END

IF @id_ram is NULL
BEGIN
	print 'RAM: '
END
ELSE
BEGIN
	print 'RAM: ' + @id_ram
END

IF @id_resource is NULL
BEGIN
	print 'Resource: '
END
ELSE
BEGIN
	print 'Resource: ' + @id_resource
END

IF @id_rootfolder is NULL
BEGIN
	print 'RootFolder: '
END
ELSE
BEGIN
	print 'RootFolder: ' + @id_rootfolder
END

IF @id_ds is NULL
BEGIN
	print 'DS: '
END
ELSE
BEGIN
	print 'DS: ' + @id_ds
END

IF @id_vsys is NULL
BEGIN
	print 'VSYS: '
END
ELSE
BEGIN
	print 'VSYS: ' + @id_vsys
END

IF @id_vsa is NULL
BEGIN
	print 'VSA: '
END
ELSE
BEGIN
	print 'VSA: ' + @id_vsa
END

-- Supression des informations dans les tables
print ' => Clean DRAAS_Topology'
DELETE FROM [dbo].[DRAAS_Topology]
WHERE [VDC_FK] = @id_vdc

print 'Delete CPU/RAM'
print ' => Put cpu & ram FK to NULL on VDC'
UPDATE [dbo].[DRAAS_VirtualResourcesInfo]
    SET [CPURESOURCES_FK] = NULL
       ,[RAMRESOURCES_FK] = NULL
WHERE [id] = @id_vdc

print ' => Clean DRAAS_HistoryItem cpu'
DELETE FROM [dbo].[DRAAS_HistoryItem]
WHERE [CPURESOURCE_FK] = @id_cpu

print ' => Clean DRAAS_HistoryItem ram'
DELETE FROM [dbo].[DRAAS_HistoryItem]
WHERE [RAMRESOURCE_FK] = @id_ram

print ' => Clean DRAAS_RamResources'
DELETE FROM [dbo].[DRAAS_RamResources]
WHERE [VDC_FK] = @id_vdc

print ' => Clean DRAAS_CpuResources'
DELETE FROM [dbo].[DRAAS_CpuResources]
WHERE [VDC_FK] = @id_vdc
print 'End of CPU/RAM'

print 'Delete Resource pool'
DELETE FROM [dbo].[DRAAS_ResourcePool]
	WHERE [VIRTUALRESOURCESINFO_FK] = @id_vdc
print 'End of Resource pool'

print 'Delete VmFolder'
print ' => Put vmfolder FK to NULL on VDC'
UPDATE [dbo].[DRAAS_VirtualResourcesInfo]
   SET [ROOTVMFOLDER_FK] = NULL
WHERE [id] = @id_vdc

print ' => Clean DRAAS_VmFolder'
DELETE FROM [dbo].[DRAAS_VmFolder]
   WHERE [id] = @id_rootfolder
print 'End of VmFolder'

print 'Delete VDC options'
DELETE FROM [dbo].[DRAAS_VdcOption]
WHERE [VDC_FK] = @id_vdc
print 'End of VDC options'

print 'Delete SubVDC'
DELETE FROM [dbo].[DRAAS_SubVDC]
WHERE [VDC_FK] = @id_vdc
print 'End of SubVDC'

print 'Delete storage'
print ' => Put datastore FK to NULL on DRAAS_Storage'
UPDATE [dbo].[DRAAS_Storage]
   SET [DATASTORE_FK] = NULL
WHERE [VDC_FK] = @id_vdc

print ' => Clean DRAAS_VmFolder'
DELETE FROM [dbo].[CLUSTERDATASTORE]
WHERE [DATASTORES_id] = @id_ds

print ' => Put datastore FK to NULL on DRAAS_Lun & put it "AVAILABLE"'
UPDATE [dbo].[DRAAS_Lun]
   SET [status] = 'AVAILABLE'
      ,[DATASTORE_FK] = NULL
WHERE [DATASTORE_FK] = @id_ds

print ' => Clean DRAAS_DataStore'
DELETE FROM [dbo].[DRAAS_DataStore]
WHERE [id] = @id_ds

print ' => Clean DRAAS_Storage'
DELETE FROM [dbo].[DRAAS_Storage]
WHERE [VDC_FK] = @id_vdc
print 'End of storage'

-- Desalocation des VSA
-- TODO Mettre une boucle pour les projets hors UCaaS
print 'Put ExtIPVPN available'
UPDATE [dbo].[DRAAS_ExtIPVPN]
   SET [vlanId] = NULL
      ,[status] = 'AVAILABLE'
WHERE [VIRTUALSYSTEMARCHITECTURE_FK] = @id_vsa
print 'End of ExtIPVPN'

print 'Put VSys available'
UPDATE [dbo].[DRAAS_VSys]
   SET [status] = 'AVAILABLE'
WHERE [id] = @id_vsys
print 'End of VSys'

print 'Put SecurityZone available'
UPDATE [dbo].[DRAAS_SecurityZone]
   SET [status] = 'AVAILABLE'
 WHERE [VIRTUALSYSTEMARCHITECTURE_FK] = @id_vsa
print 'End of SecurityZone'

print 'Put VSA available'
UPDATE [dbo].[DRAAS_Vsa]
   SET [status] = 'AVAILABLE'
      ,[VIRTUALRESOURCESINFO_FK] = NULL
 WHERE [Id] = @id_vsa
print 'End of VSA'

print 'Delete UserManualEmail'
DELETE usermail
FROM [dbo].[USERMANUALEMAIL] usermail
JOIN [dbo].[DRAAS_ManualEmail] manualemail
  ON usermail.MAILS_id = manualemail.id
WHERE manualemail.[VDC_FK] = @id_vdc
print 'End of ManualEmail'

print 'Delete UserManualEmail'
DELETE FROM [dbo].[DRAAS_ManualEmail]
WHERE [VDC_FK] = @id_vdc
print 'End of ManualEmail'

-- Supression du VCD
print 'Delete VDC'
DELETE FROM [dbo].[DRAAS_VirtualResourcesInfo]
WHERE [id] = @id_vdc
print 'End of VDC'

-- C'est fini
