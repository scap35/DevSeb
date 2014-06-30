-- Auteur : Sébastien Caprais
-- Version : 1.0
-- Mode d'emploi :
-- Remplacer dans le script la valeur de la variable @topo_to_delete avec le nom de la topo a supprimer
-- Ou forcer les valeurs plus bas


declare @topo_to_delete varchar(255)
SET @topo_to_delete = 'UCaaS Cisco (1000 users) HCS 8.6.2-V1'

-- declarations des variables
declare @id_topo numeric
declare @id_rule numeric
declare @id_version numeric
declare @nb numeric

-- recuperation des ID de la topo, version et rule
SELECT @id_topo = id from DRAAS_logicalCatalogElement
    where DTYPE = 'LogicalTopology' 
    and status = 'TOPO_DEPRECATED' 
    and elementId = @topo_to_delete
    
IF @id_topo is NULL
BEGIN
    print 'Pas de topologie de ce nom et OBSOLETE en base'
    return
END

SET @id_topo=null
SELECT @id_topo = id from DRAAS_logicalCatalogElement
where DTYPE = 'LogicalTopology' 
and status = 'TOPO_DEPRECATED' 
and id not in (select logicaltopology_fk from DRAAS_Topology)
and elementId = @topo_to_delete
IF @id_topo is NULL
BEGIN
	print 'La topologie ne peut etre supprimee car elle est instanciee'
	return
END
print 'id topo a effacer: ' + cast(@id_topo as varchar(30))

SELECT @id_rule = id from DRAAS_rule where logicaltopology_fk = @id_topo 
IF @id_rule is NULL
BEGIN
	print 'Pas de rule associee a la topologie'
END
ELSE
BEGIN
	print 'id rule a effacer: ' + cast(@id_rule as varchar(30))
END

SELECT @id_version = id from DRAAS_version where logicalCatalogElement_fk = @id_topo
IF @id_version is NULL
BEGIN
	print 'Pas de version associee a la topologie'
END
ELSE
BEGIN
	print 'id version a effacer: ' + cast(@id_version as varchar(30))
END

-- coupure du lien referentiel entre les tables 
update DRAAS_rule set logicaltopology_fk = null where id = @id_rule
update DRAAS_version set logicalCatalogElement_fk = null where id = @id_version
update DRAAS_logicalCatalogElement set version_fk = null,rulefile_fk=null where id = @id_topo

-- tables connexes
delete from LOGICALTOPOLOGYLOGICALVIRTUALAPPLICATION where LOGICALTOPOLOGYS_id = @id_topo
print 'Nombre d enregistrements effaces de la table LOGICALTOPOLOGYLOGICALVIRTUALAPPLICATION: ' + cast(@@ROWCOUNT as varchar(30))
delete from DRAAS_logicalCatalogElement where id = @id_topo
print 'Nombre d enregistrements effaces de la table DRAAS_logicalCatalogElement: ' + cast(@@ROWCOUNT as varchar(30))
delete from DRAAS_rule where id = @id_rule
print 'Nombre d enregistrements effaces de la table DRAAS_rule: ' + cast(@@ROWCOUNT as varchar(30))
delete from DRAAS_version where id = @id_version
print 'Nombre d enregistrements effaces de la table DRAAS_version: ' + cast(@@ROWCOUNT as varchar(30))

print 'topologie ' + @topo_to_delete + ' effacee de la BDD'

-- Recherche des vApp orphelines (aucune topologie n y fait reference
select @nb = count(*) FROM DRAAS_logicalCatalogElement LC1 WHERE LC1.DTYPE='LogicalVirtualApplication' and not Exists (SELECT id FROM DRAAS_logicalCatalogElement LC2 where dtype = 'LogicalVAppGroup' and LC2.LOGICALVIRTUALAPPLICATION_FK = LC1.ID)
print 'Nombre de vApps orphelines :' + cast(@nb as varchar)
-- Recherche des VMTemplates orphelins
select @nb = count(*)  FROM DRAAS_logicalCatalogElement  WHERE DTYPE='LogicalVmTemplate' and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVMTEMPLATES_id = DRAAS_logicalCatalogElement .ID)
print 'Nombre de VMTemplates orphelins :' + cast(@nb as varchar)

-- Recherche des vAppGroups orphelins
select @nb = count(*)  FROM DRAAS_logicalCatalogElement  WHERE DTYPE='LogicalVappGroup' and not Exists (SELECT LOGICALVMTEMPLATES_id FROM LOGICALVAPPGROUPLOGICALVMTEMPLATE where LOGICALVAPPGROUPLOGICALVMTEMPLATE.LOGICALVAPPGROUPS_id = DRAAS_logicalCatalogElement.ID)
print 'Nombre de vAppGroup orphelins :' + cast(@nb as varchar)