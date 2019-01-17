#Parameters
$SQL_Server = '<your SCCM SQL server>'
$Database ='<your SCCM Database>'
$Server_Collection = '<your server collection ID>'
$Workstation_Collection = '<your workstation collection ID>'

#Clients queries
$sqlCmd = "
DECLARE @date DATETIME;
SELECT @date = DATEADD([hh], -12, GETDATE());
SELECT
       (
       SELECT @date
       ) AS date,
       ISNULL((
       SELECT COUNT(DISTINCT [ResourceID]) AS [cmg_updates_scan]
              FROM [v_updatescanstatus]
              WHERE [LastScanTime] > @date
                    AND 
              [LastScanPackageLocation] LIKE '%cmg%'
              GROUP BY [LastScanPackageLocation]
       ),0) AS [cmg_updates_scan],
       ISNULL((
       SELECT COUNT(DISTINCT [Name]) [cmg_clients]
              FROM [v_CombinedDeviceResources]
              WHERE [CNIsOnInternet] = 1
                    AND [CNIsOnline] = 1
                    AND [CNAccessMP] LIKE '%cmg%'
       ),0) AS [cmg_clients],
       ISNULL((
       SELECT COUNT(DISTINCT [Name]) [MP_Clients]
              FROM [v_CombinedDeviceResources]
              WHERE [CNIsOnInternet] = 0
                    AND [CNIsOnline] = 1
       ),0) AS [MP_Clients];
"
try {
    $result = Invoke-Sqlcmd $sqlCmd  -server $SQL_Server -Database $Database
}
catch {
    return $false
}
foreach ($row in $result){
    $body='Clients CMG_Updates_Scan='+$row.cmg_updates_scan+',CMG_Clients='+$row.cmg_clients+',MP_Clients='+$row.mp_clients
    write-host $body
}
$sqlCmd1 = "
DECLARE @UserSIDs VARCHAR(16)= 'disabled';
SELECT [SYS].[Client_Version0] Client_Version,
        --[SYS].[Client_Type0],
        COUNT(*) AS 'Count'
        FROM [fn_rbac_R_System](@UserSIDs) AS [SYS]
            LEFT JOIN [fn_rbac_FullCollectionMembership](@UserSIDs) [coll] ON [coll].[ResourceID] = [sys].[ResourceID]
        WHERE [SYS].[Client0] = 1
                AND [coll].[CollectionID] = '$Server_Collection'
        GROUP BY [SYS].[Client_Version0],
                [SYS].[Client_Type0]
ORDER BY [SYS].[Client_Version0],
            [SYS].[Client_Type0]
"
try {
    $result = Invoke-Sqlcmd $sqlCmd1 -server $SQL_Server -Database $Database
}
catch {
    return $false
}
$sqlCmd2 = "
DECLARE @UserSIDs VARCHAR(16)= 'disabled';
SELECT [SYS].[Client_Version0] Client_Version,
        --[SYS].[Client_Type0],
        COUNT(*) AS 'Count'
        FROM [fn_rbac_R_System](@UserSIDs) AS [SYS]
            LEFT JOIN [fn_rbac_FullCollectionMembership](@UserSIDs) [coll] ON [coll].[ResourceID] = [sys].[ResourceID]
        WHERE [SYS].[Client0] = 1
                AND [coll].[CollectionID] = '$Workstation_Collection'
        GROUP BY [SYS].[Client_Version0],
                [SYS].[Client_Type0]
ORDER BY [SYS].[Client_Version0],
            [SYS].[Client_Type0]
"
try {
    $result2 = Invoke-Sqlcmd $sqlCmd2 -server $SQL_Server -Database $Database
}
catch {
    return $false
}

foreach ($row in $result){
    $cv=$row.client_version
    $c=$row.count
    $time=get-date -Format filedatetime
    $body="Servers,ClientVersion="+$cv+" Count="+$c
    write-host $body.trim()
}
foreach ($row in $result2){
    $cv=$row.client_version
    $c=$row.count
    $time=get-date -Format filedatetime
    $body="Workstations,ClientVersion="+$cv+" Count="+$c
    write-host $body.trim()
}
$sqlCmd = "
WITH CTE
     AS (
     SELECT DISTINCT
            CASE
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 5.%'
                THEN 'WindowsXP'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 6.0%'
                THEN 'WindowsVista'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 6.1%'
                THEN 'Windows7'
                WHEN [Systems].[Operating_System_Name_And0] LIKE 'Windows_7 Entreprise 6.1'
                THEN 'Windows7'
                WHEN [Systems].[Operating_System_Name_And0] = 'Windows Embedded Standard 6.1'
                THEN 'Windows7'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 6.2%'
                THEN 'Windows8'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 6.3%'
                THEN 'Windows8_1'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 10%'
                THEN 'Windows10'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 10%'
                THEN 'Windows10'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 5.%'
                THEN 'WindowsServer2003'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 6.0%'
                THEN 'WindowsServer2008'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 6.1%'
                THEN 'WindowsServer2008R2'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 6.2%'
                THEN 'WindowsServer2012'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 6.3%'
                THEN 'WindowsServer2012R2'
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 10%'
                THEN(CASE
                         WHEN CAST(REPLACE([Build01], '.', '') AS INT) > 10017763
                         THEN 'WindowsServer2019'
                         ELSE 'WindowsServer2016'
                     END)
                ELSE [Systems].[Operating_System_Name_And0]
            END AS [OS],
            CASE
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Workstation 10%'
                THEN(CASE REPLACE([Systems].[Build01], '.', '')
                         WHEN '10010240'
                         THEN '1507'
                         WHEN '10010586'
                         THEN '1511'
                         WHEN '10014393'
                         THEN '1607'
                         WHEN '10015063'
                         THEN '1703'
                         WHEN '10016299'
                         THEN '1709'
                         WHEN '10017134'
                         THEN '1803'
                         WHEN '10017763'
                         THEN '1809'
                         ELSE 'N/A'
                     END)
                WHEN [Systems].[Operating_System_Name_And0] LIKE '%Server 10%'
                THEN(CASE REPLACE([Systems].[Build01], '.', '')
                         WHEN '10014393'
                         THEN '1607'
                         WHEN '10016299'
                         THEN '1709'
                         WHEN '10017134'
                         THEN '1803'
                         WHEN '10017763'
                         THEN '1809'
                         ELSE 'N/A'
                     END)
                ELSE 'N/A'
            END AS [OSVersion],
            COUNT(DISTINCT [Systems].[Name0]) AS [OScount],
            ISNULL([Systems].[Build01], 0) AS [Build01]
            FROM [v_R_System] [Systems]
            WHERE [Systems].[operatingSystem0] IS NOT NULL
            GROUP BY [Operating_System_Name_And0],
                     [Build01])
     SELECT DISTINCT
            [OS],
            [OSVersion],
            [OSType] = (CASE
                            WHEN [OS] LIKE 'WindowsServer%'
                            THEN 'Servers'
                            WHEN [OS] LIKE 'Windows%'
                            THEN 'Workstations'
                            ELSE 'Unknowns'
                        END),
            Count =
            (
            SELECT SUM([OSCount])
                   FROM [CTE] AS [Summary]
                   WHERE [Summary].[OS] = [CTE].[OS]
                         AND [Summary].[OSVersion] = [CTE].[OSVersion]
            )
            FROM [CTE]
            GROUP BY [OS],
                     [OSVersion],
                     [Build01]
     ORDER BY [OS],
              [OSVersion],
              Count;
"
try {
    $result = Invoke-Sqlcmd $sqlCmd -server $SQL_Server -Database $Database
}
catch {
    return $false
}
foreach ($row in $result){
    $OS=$row.OS -replace " ","_"
    $body=$row.OSType+'Versions,OS=_'+$OS+',OSVersion=_'+$row.OSVersion+' Count='+$row.count
    write-host $body
}
$sqlCmd = "
SELECT UPPER(SUBSTRING([PSD].[ServerNALPath], 13, CHARINDEX('.', [PSd].[ServerNALPath])-13)) AS [DP_Name],
       COUNT(CASE
                 WHEN [PSD].State NOT IN('0', '3', '6')
                 THEN '*'
             END) AS 'Not_Installed',
       COUNT(CASE
                 WHEN [PSD].State IN('3', '6')
                 THEN '*'
             END) AS 'Error',
       (CASE
            WHEN [PSD].State = '0'
            THEN '1'--'OK' 
            WHEN [PSD].State NOT IN('0', '3', '6')
            THEN '2'--'In_Progress'
            WHEN [PSD].State IN('3', '6')
            THEN '3'--'Error'
        END) AS 'Status'
INTO [#tmp_st]
       FROM [$Database].[dbo].[v_PackageStatusDistPointsSumm] [psd],
            [$Database].[dbo].[SMSPackages] [P]
       WHERE [p].[PackageType] != 4
             AND ([p].[PkgID] = [psd].[PackageID])
       GROUP BY [PSd].[ServerNALPath],
                [PSD].State;

SELECT 
       SUM([d].[Not_Installed]) [PKG_Not_Installed],
       SUM([d].[error]) [PKG_Error],
       (
       SELECT COUNT([dp_name])
              FROM [#tmp_st]
              WHERE [status] = '1'
       ) [DP_OK],
       (
       SELECT COUNT([dp_name])
              FROM [#tmp_st]
              WHERE [status] = '2'
       ) [DP_In_Progress],
       (
       SELECT COUNT([dp_name])
              FROM [#tmp_st]
              WHERE [status] = '3'
       ) [DP_Error]
       FROM [#tmp_st] [d];


DROP TABLE [#tmp_st];
"
try {
    $result = Invoke-Sqlcmd $sqlCmd  -server $SQL_Server -Database $Database
}
catch {
    return $false
}
foreach ($row in $result){
    $body='DistributionPoints DP_OK='+$row.DP_OK+',PKG_Not_Installed='+$row.PKG_Not_Installed+',PKG_Error='+$row.PKG_Error+',DP_In_Progress='+$row.DP_In_Progress+',DP_Error='+$row.DP_Error
    write-host $body
}

##distribution

$sqlCmd = "
DECLARE @StartDate DATE;
SET @StartDate = DATEADD([d], -7, GETDATE());
DECLARE @EndDate DATE;
SET @EndDate = GETDATE();

WITH ClientDownloadHist
     AS (
     SELECT [his].[ID],
            [his].[ClientId],
            [his].[StartTime],
            [his].[BytesDownloaded],
            [his].[ContentID],
            [his].[DistributionPointType],
            [his].[DownloadType],
            [his].[HostName],
            [his].[BoundaryGroup]
            FROM [v_ClientDownloadHistoryDP_BG] [his]
            WHERE [his].[DownloadType] = 0
                  AND [his].[StartTime] >= @StartDate
                  AND ([his].[StartTime] >= @StartDate
                       AND [his].[StartTime] <= @EndDate)),
     ClientsDownloadBytes
     AS (
     SELECT [BoundaryGroup],
            ISNULL(SUM([x].[SpBytes]), 0) AS [PeerCacheBytes],
            ISNULL(SUM([x].[DpBytes]), 0) AS [DistributionPointBytes],
            ISNULL(SUM([x].[CloudDpBytes]), 0) AS [CloudDistributionPointBytes],
            ISNULL(SUM([x].[BranchCacheBytes]), 0) AS [BranchCacheBytes],
            ISNULL(SUM([x].[TotalBytes]), 0) AS [TotalBytes]
            FROM
                 (
                 SELECT [BoundaryGroup],
                        [DistributionPointType],
                        [SpBytes] = ISNULL(SUM(IIF([DistributionPointType] = 3, [BytesDownloaded], 0)), 0),
                        [DpBytes] = ISNULL(SUM(IIF([DistributionPointType] = 4, [BytesDownloaded], 0)), 0),
                        [BranchCacheBytes] = ISNULL(SUM(IIF([DistributionPointType] = 5, [BytesDownloaded], 0)), 0),
                        [CloudDpBytes] = ISNULL(SUM(IIF([DistributionPointType] = 1, [BytesDownloaded], 0)), 0),
                        [TotalBytes] = SUM([BytesDownloaded])
                        FROM [ClientDownloadHist]
                        GROUP BY [BoundaryGroup],
                                 [DistributionPointType]
                 ) AS [x]
            GROUP BY [BoundaryGroup]),
     Peers([BoundaryGroup],
           [PeerClientCount])
     AS (
     SELECT [his].[BoundaryGroup],
            COUNT(DISTINCT([ResourceID]))
            FROM [v_SuperPeers] [sp]
                 JOIN [ClientDownloadHist] [his] ON [his].[ClientId] = [sp].[ResourceID]
            GROUP BY [his].[BoundaryGroup]),
     DistPoints([BoundaryGroup],
                [CloudDPCount],
                [DPCount])
     AS (
     SELECT [bgs].[GroupId],
            SUM(IIF([sysres].[NALResType] = 'Windows Azure', 1, 0)),
            SUM(IIF([sysres].[NALResType] <> 'Windows Azure', 1, 0))
            FROM [vSMS_SC_SysResUse] [sysres]
                 JOIN [vSMS_BoundaryGroupSiteSystems] [bgs] ON [bgs].[ServerNALPath] = [sysres].[NALPath]
            WHERE [RoleTypeID] = 3
            GROUP BY [bgs].[GroupId])
     SELECT --[bg].[Name] AS [BoundaryGroupName],
     ISNULL(sum(ISNULL([cdb].[BranchCacheBytes], 0))/1073741824,0) AS [BranchCache_GB],
     ISNULL(sum(ISNULL([cdb].[CloudDistributionPointBytes], 0))/1073741824,0) AS [CloudDP_GB],
     ISNULL(sum(ISNULL([cdb].[DistributionPointBytes], 0))/1073741824,0) AS [DP_GB],
     ISNULL(sum(ISNULL([cdb].[PeerCacheBytes], 0))/1073741824,0) AS [PeerCache_GB]
            FROM [BoundaryGroup] [bg]
                 LEFT JOIN [Peers] AS [p] ON [p].[BoundaryGroup] = [bg].[GroupID]
                 LEFT JOIN [DistPoints] AS [dp] ON [dp].[BoundaryGroup] = [bg].[GroupID]
                 LEFT JOIN [ClientsDownloadBytes] AS [cdb] ON [cdb].[BoundaryGroup] = [bg].[GroupID]
            WHERE [cdb].[TotalBytes] > 0
			and [bg].[Name] not like '%servers%'
"
try {
    $result = Invoke-Sqlcmd $sqlCmd  -server $SQL_Server -Database $Database
}
catch {
    return $false
}
foreach ($row in $result){
    $body='Content_WKS '+'BranchCache='+$row.BranchCache_GB+',CloudDP='+$row.CloudDP_GB+',DP='+$row.DP_GB+',PeerCache='+$row.PeerCache_GB
    write-host $body
}
