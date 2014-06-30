-- Auteur : Sébastien Caprais
-- Version : 1.0
-- Mode d'emploi : lancer le script sans parametre
-- Description
-- Efface les enregistrements de la table DRAAS_logicalCatalogElement de type :
-- 1) LogicalVmTemplate et qui ne sont pas associes a un vAppGroup
-- 2) LogicalVappGroup et qui ne sont pas associes a une vApp
-- 3) LogicalVirtualApplication et qui ne sont pas associes a une topologie
--
-- Pour tout nettoyer : delete from LOGICALVAPPGROUPLOGICALVMTEMPLATE


declare @v_id char(11)
declare @nb numeric
declare @IdList1 table (Id int primary key)
declare @IdList2 table (Id int primary key)

-- DRAAS_version : noter les ID pour les supprimer a la fin
-- recherche des ID des VMT qui ne sont pas associes a des vAppGroup, ni a des VMT physiques
insert into @IdList1 (Id)
		select ID FROM DRAAS_logicalCatalogElement 
		WHERE DTYPE='LogicalVmTemplate' 
		and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVMTEMPLATES_id = DRAAS_logicalCatalogElement.ID)
		and not Exists (SELECT LOGICALVMTEMPLATE_FK FROM DRAAS_VirtualMachine where LOGICALVMTEMPLATE_FK = DRAAS_logicalCatalogElement.ID)

insert into @IdList2 (Id)
	select id from draas_version where LOGICALCATALOGELEMENT_FK 
	in (select Id from @IdList2)

-- couper le lien entre DRAAS_version et DRAAS_logicalCatalogElement
update DRAAS_version set LOGICALCATALOGELEMENT_FK = null where LOGICALCATALOGELEMENT_FK in (select ID FROM DRAAS_logicalCatalogElement WHERE DTYPE='LogicalVmTemplate' and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVMTEMPLATES_id = DRAAS_logicalCatalogElement.ID))
update DRAAS_logicalCatalogElement set VERSION_FK = null where DTYPE='LogicalVmTemplate' and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVMTEMPLATES_id = DRAAS_logicalCatalogElement.ID)

-- supprimer les enregistrements de DRAAS_version lies aux VMT a supprimer
delete from DRAAS_version where id in (select Id from @IdList2)
print 'Nombre d enregistrements effaces de la table DRAAS_version: ' + cast(@@ROWCOUNT as varchar(30))

-- nettoyage des tables temporaires
delete from @IDList1
delete from @IDList2


-- VMtemplatemiddleware : suppression directe 
delete from VMtemplatemiddleware where LOGICALVMTEMPLATES_id in (select ID FROM DRAAS_logicalCatalogElement WHERE DTYPE='LogicalVmTemplate' and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVMTEMPLATES_id = DRAAS_logicalCatalogElement.ID))
print 'Nombre de VMtemplatemiddleware effaces: ' + cast(@@ROWCOUNT as varchar(30))

-- supprimer le VMT logique : il ne doit pas appartenir a un vAppGroup, ni etre reference dans DRAAS_VirtualMachine
delete FROM DRAAS_logicalCatalogElement WHERE DTYPE='LogicalVmTemplate' 
and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVMTEMPLATES_id = DRAAS_logicalCatalogElement.ID)
and DRAAS_logicalCatalogElement.ID not in (select LOGICALVMTEMPLATE_FK from DRAAS_VirtualMachine where LOGICALVMTEMPLATE_FK is not null)
print 'Nombre de VMT logiques effaces: ' + cast(@@ROWCOUNT as varchar(30))

-- effacer les vAppGroup orphelins 
delete FROM DRAAS_logicalCatalogElement  WHERE DTYPE='LogicalVappGroup' and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVAPPGROUPS_id = DRAAS_logicalCatalogElement.ID)
print 'Nombre de vAppGroup effaces: ' + cast(@@ROWCOUNT as varchar(30))

-- effacer les vApp orphelines (aucun vAppGroup n y fait reference)
delete FROM DRAAS_logicalCatalogElement WHERE DRAAS_logicalCatalogElement.DTYPE='LogicalVirtualApplication' and not Exists (SELECT id FROM DRAAS_logicalCatalogElement LC2 where dtype = 'LogicalVAppGroup' and LC2.LOGICALVIRTUALAPPLICATION_FK = DRAAS_logicalCatalogElement.ID)
print 'Nombre de vApps orphelines :' + cast(@@ROWCOUNT as varchar(30))