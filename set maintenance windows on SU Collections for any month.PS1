<# 
********************************************************************************************************** 
*                                                                                                        * 
*** This Powershell Script is used to set maintenance windows on SU Collections for any month          *** 
*                                                                                                        * 
********************************************************************************************************** 
* Created by Octavian Cordos, 28/03/2015  | Requirements Powershell 2.0, SCCM 2012 R2                    * 
* =======================================================================================================* 
* Modified by                   |    Date    | Revision  | Comments                                      * 
*________________________________________________________________________________________________________* 
* Octavian Cordos               | 28/03/2015 | v1.0      | First version                                 * 
* Octavian Cordos/Ioan Popovici | 30/03/2015 | v1.1      | Second version                                * 
* Octavian Cordos               | 31/03/2015 | v1.2      | Third version                                 * 
*--------------------------------------------------------------------------------------------------------* 
*                                                                                                        * 
********************************************************************************************************** 
 
    .SYNOPSIS 
       Used to set maintenance windows 
    .DESCRIPTION 
       Calculating second tuesday of any month and setting Maintenance window offset by any number of days/weeks 
#> 
 
#Run on Site server 
 
#Initialising 
    import-module "E:\SCCM\AdminConsole\bin\ConfigurationManager.psd1" 
    cd VSM: 
 
#Parameters 
    $MonthArray = New-Object System.Globalization.DateTimeFormatInfo 
    $MonthNames = $MonthArray.MonthNames 
    $CollectionID="VSM000C7" 
    $PatchMonth=4 
    $OffSetDays=3 
    $OffSetWeeks=1 
  
#Set Patch Tuesday for a Month 
Function Get-PatchTuesday ([int] $Month)  
 { 
    $FindNthDay=2 #Aka Second occurence 
    $WeekDay='Tuesday' 
    $Today=get-date -Month $Month 
    $todayM=$Today.Month.ToString() 
    $todayY=$Today.Year.ToString() 
    [datetime]$StrtMonth=$todayM+'/1/'+$todayY 
    while ($StrtMonth.DayofWeek -ine $WeekDay ) { $StrtMonth=$StrtMonth.AddDays(1) } 
    $PatchDay=$StrtMonth.AddDays(7*($FindNthDay-1)) 
    return $PatchDay 
 } 
 
Function Set-PatchMW ([int]$PatchMonth, [int]$OffSetDays, [int] $OffSetWeeks, [string] $CollID) 
 { 
 
    #Set Patch Tuesday for each Month 
    $PatchDay=Get-PatchTuesday($PatchMonth) 
         
    #Set Maintenance Window Naming Convention (Months array starting from 0 hence the -1) 
    $MWName =  "MW."+$MonthNames[$PatchMonth-1]+".Week"+$OffSetWeeks 
 
    #Set Device Collection Maintenace interval  
    $StartTime=$PatchDay.AddDays($OffSetDays).AddMinutes(30) 
    $EndTime=$StartTime.Addhours(5).AddMinutes(30) 
 
    #Create The Schedule Token  
    $Schedule = New-CMSchedule -Nonrecurring -Start $StartTime.AddDays($OffSetWeeks*7) -End $EndTime.AddDays($OffSetWeeks*7) 
 
    #Set Maintenance Windows 
    New-CMMaintenanceWindow -CollectionID $CollID -Schedule $Schedule -Name $MWName -ApplyToSoftwareUpdateOnly 
} 
 
#Remove all existing Maintenance Windows for a Collection 
Function Remove-MaintnanceWindows ([string]$CollID)  
{ 
    Get-CMMaintenanceWindow -CollectionId $CollID | ForEach-Object { 
        Remove-CMMaintenanceWindow -CollectionID $CollID -Name $_.Name -Force 
        $Coll=Get-CMDeviceCollection -CollectionId $CollID 
        Write-Host "Removing MW:"$_.Name"- From Collection:"$Coll.Name 
    } 
} 
 
#Remove Previous Maintenance Windows 
Remove-MaintnanceWindows $CollID 
 
Set-PatchMW $PatchMonth $OffSetDays $OffSetWeeks $CollectionID 
 
#Or use it like this for the whole Year 
#For ($Month = 1; $Month -le 12; $Month++)  
#    { 
#    Set-PatchMW $Month $OffSetDays $OffSetWeeks $CollectionID 
#    }