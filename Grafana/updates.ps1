#Parameters
$SQL_Server = 'sql.server.fqdn'
$Database ='CM_XXX'
[string]$dirfiles = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$coll_stats = Import-Csv $dirfiles'\coll_stats.csv'

#Functions
Function Server_Versions{
    [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true)]
            [Alias('CollID')]
            [String]$Coll_ID,
            [Parameter(Mandatory = $true)]
            [Alias('FilterName')]
            [String]$Filter_Name
            )
    $sqlCmd = "
    SELECT distinct
    --[a].[operatingSystem0],
     CASE
               WHEN [a].[operatingSystem0] LIKE '%2008 R2%'
               THEN '2008R2'
               WHEN [a].[operatingSystem0] LIKE '%2008%'
               THEN '2008'
               WHEN [a].[operatingSystem0] LIKE '%2003%'
               THEN '2003'
               WHEN [a].[operatingSystem0] LIKE '%2012 R2%'
               THEN '2012_R2'
               WHEN [a].[operatingSystem0] LIKE '%2012%'
               THEN '2012'
               WHEN [a].[operatingSystem0] LIKE '%2016%'
               THEN '2016'
		       WHEN [a].[operatingSystem0] LIKE '%2019%'
               THEN '2019'
           END AS [OS],
           --iif([C].[Value] is null,0,[C].[Value]) AS [Build],
           COUNT(DISTINCT [A].[Name0]) AS [count]
           FROM $Database.dbo.[v_R_System] [A]
                LEFT OUTER JOIN $Database.dbo.[vSMS_WindowsServicingStates] [B] ON [B].[Build] = [A].[Build01]
                                                                     AND (([B].[Branch] = [A].[OSBranch01])
                                                                          OR ([A].[OSBranch01] = ''
                                                                              AND [B].[Branch] = 0))
                LEFT OUTER JOIN $Database.dbo.[vSMS_WindowsServicingLocalizedNames] [C] ON [B].[Name] = [C].[Name]
                LEFT JOIN $Database.[dbo].[v_FullCollectionMembership] [vc] ON [vc].[ResourceID] = [A].[ResourceID]
           WHERE [a].[operatingSystem0] IS NOT NULL
                 AND [a].[operatingSystem0] LIKE '%server %'
                 AND [vc].[CollectionID] = '$Coll_ID'
    group by
     CASE
               WHEN [a].[operatingSystem0] LIKE '%2008 R2%'
               THEN '2008R2'
               WHEN [a].[operatingSystem0] LIKE '%2008%'
               THEN '2008'
               WHEN [a].[operatingSystem0] LIKE '%2003%'
               THEN '2003'
               WHEN [a].[operatingSystem0] LIKE '%2012 R2%'
               THEN '2012_R2'
               WHEN [a].[operatingSystem0] LIKE '%2012%'
               THEN '2012'
               WHEN [a].[operatingSystem0] LIKE '%2016%'
               THEN '2016'
		       WHEN [a].[operatingSystem0] LIKE '%2019%'
               THEN '2019'
           END--,[C].[Value]
 
    "
    try {
        $result = Invoke-Sqlcmd $sqlCmd -server $SQL_Server -Database $Database
    }
    catch {
        ##return $false
    }
    foreach ($row in $result){
        $body=$Filter_Name+'.Versions,Server=_'+$row.OS+' Count='+$row.count
        write-host $body
    }
}
Function SCEP{
    [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true)]
            [Alias('CollID')]
            [String]$Coll_ID,
            [Parameter(Mandatory = $true)]
            [Alias('CollType')]
            [String]$Coll_Type,
            [Parameter(Mandatory = $true)]
            [Alias('FilterName')]
            [String]$Filter_Name
        ) 
    $sqlCmd = "
    SELECT TOP 5 [ep].[AntivirusSignatureVersion],
                    COUNT([ep].[AntivirusSignatureVersion]) [Count],
                    '$Filter_Name' AS [Filter]
        into #temp_scep_$Coll_Type
            FROM [v_GS_AntimalwareHealthStatus] [ep]
                LEFT JOIN [$Database].[dbo].[v_FullCollectionMembership] [vc] ON [vc].[ResourceID] = [ep].[ResourceID]
            WHERE [vc].[CollectionID] = '$Coll_ID'
            GROUP BY [ep].[AntivirusSignatureVersion]
    ORDER BY 2 DESC;

    INSERT INTO #temp_scep_$Coll_Type
    ([AntivirusSignatureVersion],
     [Count],
     [Filter]
    )
    VALUES
    ('Other',
           (
           SELECT COUNT([ep].[AntivirusSignatureVersion]) [Count]
                  FROM [v_GS_AntimalwareHealthStatus] [ep]
                       LEFT JOIN [$Database].[dbo].[v_FullCollectionMembership] [vc] ON [vc].[ResourceID] = [ep].[ResourceID]
                  WHERE [vc].[CollectionID] = '$Coll_ID'

           )-
           (
           SELECT SUM([count])
                  FROM #temp_scep_$Coll_Type
           ),
     '$Filter_Name'
    )
    SELECT [scep].[AntivirusSignatureVersion],
       isnull([scep].Count, 0) Count,
       [scep].[Filter]
       FROM [#temp_scep_$Coll_Type] [scep];
    drop table #temp_scep_$Coll_Type
    "
    try {
        $result = Invoke-Sqlcmd $sqlCmd  -server $SQL_Server -Database $Database
    }
    catch {
        #return $false
    }
    foreach ($row in $result){
        #$compliance=$row.compliance -replace ' ','_'
        $body=$row.filter+'.SCEP,AntivirusSignatureVersion=_'+$row.AntivirusSignatureVersion+' Count='+$row.count
        write-host $body
    }

}
Function Updates_Last{
    [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true)]
            [Alias('CollID')]
            [String]$Coll_ID,
            [Parameter(Mandatory = $true)]
            [Alias('CollType')]
            [String]$Coll_Type,
            [Parameter(Mandatory = $true)]
            [Alias('FilterName')]
            [String]$Filter_Name
        )    
    $sqlCmd = "
    SELECT '$Filter_Name' AS [filter],
           [s].[compliance],
           COUNT([s].[name]) AS [status]
           FROM [grafana].[dbo].[$Coll_Type] as [s]
                LEFT JOIN [$Database].[dbo].[v_FullCollectionMembership] [vc] ON [vc].[resourceID] = [s].[ResourceID]
           WHERE [vc].[CollectionID] = '$Coll_ID'
	       and [s].[filter]='$Coll_Type.Patching.Required.Last'
           GROUP BY [filter],
                    [compliance]
    "
    try {
        $result = Invoke-Sqlcmd $sqlCmd  -server $SQL_Server -Database $Database
    }
    catch {
        #return $false
    }
    foreach ($row in $result){
        $compliance=$row.compliance -replace ' ','_'
        $body=$row.filter+'.Last '+$compliance+'='+$row.status
        write-host $body
    }
}

## Overall SERVERS ##
$sqlCmd = "
SELECT [filter],
       [compliance],
       COUNT([name]) AS [status]
       FROM [grafana].[dbo].[Servers]
       GROUP BY [filter],
                [compliance]
"
try {
    $result = Invoke-Sqlcmd $sqlCmd -server $SQL_Server -Database $Database
}
catch {
    #return $false
}
foreach ($row in $result){
    $compliance=$row.compliance -replace ' ','_'
    $body=$row.filter+' '+$compliance+'='+$row.status
    write-host $body
}

## Overall WORKSTATIONS ##
$sqlCmd = "
SELECT [filter],
       [compliance],
       COUNT([name]) AS [status]
       FROM [grafana].[dbo].[Workstations]
       GROUP BY [filter],
                [compliance]
"
try {
    $result = Invoke-Sqlcmd $sqlCmd  -server $SQL_Server -Database $Database
}
catch {
    #return $false
}
foreach ($row in $result){
    $compliance=$row.compliance -replace ' ','_'
    $body=$row.filter+' '+$compliance+'='+$row.status
    write-host $body
}

#MWs
$sqlCmd = "
delete from [grafana].dbo.MW
insert into [grafana].dbo.MW
SELECT [cv].[CollectionName],
       [sw].[Name],
       [sw].[Description],
       [sw].[StartTime],
       DATEADD([mi], [sw].[duration], [sw].[starttime]) [Endtime]

       FROM [v_ServiceWindow] [sw]
            LEFT JOIN [v_Collections] [cv] ON [sw].[CollectionID] = [cv].[siteid]
       WHERE [sw].[StartTime] > GETDATE()
             AND [sw].[IsEnabled] = 1
             AND [sw].[StartTime] < (DATEADD([d], 14, GETDATE()));	
"
try {
    $result = Invoke-Sqlcmd $sqlCmd -server $SQL_Server -Database $Database
}
catch {
    #return $false
}

## FROM CSV ##
foreach ($Entry in $coll_stats) {
    if ($Entry.UpdatesLast -eq 'True'){
        Updates_Last -CollID $Entry.CollID -CollType $Entry.CollType -FilterName $Entry.FilterName
    }
    if ($Entry.SCEP -eq 'True'){
        SCEP -CollID $Entry.CollID -CollType $Entry.CollType -FilterName $Entry.FilterName
    }
    Server_versions -CollID $Entry.CollID -FilterName $Entry.FilterName
}
