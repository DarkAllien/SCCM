Function get-tsm_content {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('SourceLocation')]
        [String]$Source,
        [Alias('PatternMatch')]
        [String]$Pattern
    )
    $TCPPORT = Select-String -Path $Source -pattern $Pattern
    return $TCPPORT.ToString().Split("	").Split(" ")[-1]
}
   
#cleaning WMI calss
Get-WmiObject -Query "SELECT * FROM Tivoli" -Namespace root\cimv2 | Remove-WmiObject
   
#Creating WMI class with properties
$newClass = New-Object System.Management.ManagementClass ("root\cimv2", [String]::Empty, $null); 
   
$newClass["__CLASS"] = "Tivoli"; 
$newClass.Qualifiers.Add("Static", $true)
$newClass.Properties.Add("TCPPORT", [System.Management.CimType]::String, $false)
$newClass.Properties["TCPPORT"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("TCPServeraddress", [System.Management.CimType]::String, $false)
$newClass.Properties["TCPServeraddress"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("Source", [System.Management.CimType]::String, $false)
$newClass.Properties["Source"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("Date", [System.Management.CimType]::String, $false)
$newClass.Properties["Date"].Qualifiers.Add("Key", $true)
$newClass.Put()
   
#getting content from BAClient
$Source = 'C:\Program Files\Tivoli\TSM\baclient\dsm.opt'
$Pattern1 = "TCPPORT"
$Pattern2 = "TCPSERVERADDR"
$date = (get-date).ToString()

   
$TCPPORT = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern1
$TCPServeraddress = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern2
   
#writing data to wmi
New-CimInstance -ClassName Tivoli -Property @{TCPPORT = $TCPPORT; TCPServeraddress = $TCPServeraddress; Source = $Source; Date = $date}
   
#getting data from TSM Folders in local drives
#getting local drives
$drives = GET-ciminstance  –query “SELECT * from win32_logicaldisk where DriveType = 3” | Select-Object DeviceID
   
#getting content from TSM folders on each drives
ForEach ($Location in $drives) {
    Try {
        $Source = $Location.DeviceID + '\TSM\dsm.opt'
        $TCPPORT = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern1
        $TCPServeraddress = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern2
        New-CimInstance -ClassName Tivoli -Property @{TCPPORT = $TCPPORT; TCPServeraddress = $TCPServeraddress; Source = $Source; Date = $date}
           
        $Source = $Location.DeviceID + '\TSM\dsm_m.opt'
        $TCPPORT = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern1
        $TCPServeraddress = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern2
        New-CimInstance -ClassName Tivoli -Property @{TCPPORT = $TCPPORT; TCPServeraddress = $TCPServeraddress; Source = $Source; Date = $date}
           
        $Source = $Location.DeviceID + '\TSM\dsm_y.opt'
        $TCPPORT = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern1
        $TCPServeraddress = get-tsm_content -SourceLocation $Source -PatternMatch $Pattern2
        New-CimInstance -ClassName Tivoli -Property @{TCPPORT = $TCPPORT; TCPServeraddress = $TCPServeraddress; Source = $Source; Date = $date}
    }
    Catch {
        #  Not needed, empty
    }
}