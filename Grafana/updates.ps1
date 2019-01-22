#Parameters
$SQL_Server = '<your SCCM SQL server FQDN>'
$Database ='<your SCCM Database>'
[string]$dirfiles = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$coll_stats = Import-Csv $dirfiles'\coll_stats.csv'

#Functions
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
}
