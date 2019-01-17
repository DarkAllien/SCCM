$exists = ''

$exists = Get-CimInstance -ClassName tivoli -ErrorAction SilentlyContinue

if ($exists.length -eq 0) {
    return $false
}
else {
    foreach ($date in $exists.date) {
        $date2 = get-date
        $ts = New-TimeSpan -Start $date -End $date2
        if ($ts.Days -gt 1) {
            return $false
        }
        else {
            return $true
        }
    }
}