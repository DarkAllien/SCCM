DECLARE @UserSIDs VARCHAR(16) = 'disabled';
DECLARE @CollID VARCHAR(8)= 'CollID for Testing';

declare @AuthListLocalID as int
select @AuthListLocalID=CI_ID from v_AuthListInfo 
where CI_UniqueID=@AuthListID

SELECT DISTINCT
       [rs].[NetBios_Name0] AS [Name],
       CASE
           WHEN [os].[Caption0] LIKE '%2003%' THEN '2003'
           WHEN [os].[Caption0] LIKE '%2008 R2%' THEN '2008 R2'
           WHEN [os].[Caption0] LIKE '%2008%' THEN '2008'
           WHEN [os].[Caption0] LIKE '%2012 R2%' THEN '2012 R2'
           WHEN [os].[Caption0] LIKE '%2012%' THEN '2012'
           ELSE 'Other'
       END AS [Osys],
       CASE
           WHEN [cs].[Roles0] LIKE '%Domain_Controller%' THEN 'DC'
           WHEN [rs].[Distinguished_Name0] LIKE '%DC=company,DC=net%' THEN 'company.net'
           WHEN [rs].[Resource_Domain_OR_Workgr0] LIKE '%domain%' THEN 'domain'
           ELSE 'Other'
       END AS [Role],
       CASE
           WHEN [os].[CSDVersion0] LIKE '%1%' THEN '1'
           WHEN [os].[CSDVersion0] LIKE '%2%' THEN '2'
           WHEN [os].[CSDVersion0] LIKE '%3%' THEN '3'
           WHEN [os].[CSDVersion0] LIKE '%4%' THEN '4'
           WHEN [os].[CSDVersion0] LIKE '%5%' THEN '5'
       END AS [SP],
       [ucsa].[ResourceID],
       [ui].[BulletinID],
       [ui].[ArticleID],
       [ui].[Title],
       [ui].[Description],
       [ui].[DateRevised],
       CASE [ui].[Severity]
           WHEN 10 THEN 'Critical'
           WHEN 8 THEN 'Important'
           WHEN 6 THEN 'Moderate'
           WHEN 2 THEN 'Low'
           ELSE '(Unknown)'
       END AS [Severity]
FROM   [v_UpdateComplianceStatus] [ucsa]
       INNER JOIN [v_CIRelation] [cir] ON [ucsa].[CI_ID] = [cir].[ToCIID]
       INNER JOIN [v_UpdateInfo] [ui] ON [ucsa].[CI_ID] = [ui].[CI_ID]
       JOIN [v_R_System] [rs] ON [ucsa].[ResourceID] = [rs].[ResourceID]
       LEFT JOIN [dbo].[v_GS_COMPUTER_SYSTEM] [CS] ON [rs].[ResourceID] = [CS].[ResourceID]
       JOIN [v_GS_OPERATING_SYSTEM] AS [os] ON [ucsa].[ResourceID] = [os].[ResourceID]
WHERE  [cir].[RelationType] = 1
       AND [ucsa].[ResourceID] IN
(
    SELECT [vc].[ResourceID]
    FROM   [v_FullCollectionMembership] [vc]
    WHERE  [vc].[CollectionID] = @CollID
)
       AND [ucsa].[Status] = '2' --Required
       AND [cir].[FromCIID] = @AuthListLocalID;
