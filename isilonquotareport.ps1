##Powershell script to get quota information from Iislon
##and email the information per quota populated from CSV "path,reportemail"
##Using the Isilon powershell module by Christoper Banck https://github.com/vchrisb/Isilon-POSH
##Import module to turn off self-signed cert error that stops rest api calls 
#Add these powershell modules into your powershell env.
Import-Module SSLValidation
Import-Module IsilonPlatform
Disable-SSLValidation
$ISILON = "isilon.emc.com"
#excluded home drives 
$excludePath = "/ifs/home"
$SMTPServer = "smtp.org.com"
$SMTPPort = "25"
$EmailFrom = "isilon.emc.com"
#function to pick the right byte conversion 
Function Get-OptimalSize()
{
    Param([int64]$sizeInBytes)
    switch ($sizeInBytes)
    {
        {$sizeInBytes -ge 1TB} {"{0:n$sigDigits}" -f ($sizeInBytes/1TB) + " TB" ; break}
        {$sizeInBytes -ge 1GB} {"{0:n$sigDigits}" -f ($sizeInBytes/1GB) + " GB" ; break}
        {$sizeInBytes -ge 1MB} {"{0:n$sigDigits}" -f ($sizeInBytes/1MB) + " MB" ; break}
        {$sizeInBytes -ge 1KB} {"{0:n$sigDigits}" -f ($sizeInBytes/1KB) + " KB" ; break}
        Default { "{0:n$sigDigits}" -f $sizeInBytes + " Bytes" }
    } # EndSwitch
}
#connect to isilon session
New-isiSession -ComputerName $isilon -Credential ChangeAccount 
#path for import of CSV file
#format is path,reportemail
$csv_info = Import-Csv "C:\Users\admin\reportpaths.csv"


foreach ($line in $csv_info){
$emailBody = @()
$quotas = Get-isiQuotas -path $line.path
$soft = Get-OptimalSize $quotas.thresholds.soft
$freespace = Get-OptimalSize ($quotas.thresholds.soft - $quotas.usage.logical)
$usedspace = Get-OptimalSize ($quotas.thresholds.soft - ($quotas.thresholds.soft - $quotas.usage.logical))
$advisoryLimit = Get-OptimalSize $quotas.thresholds.advisory
$obj = New-Object PSObject  
$obj | Add-Member  "Path" $line.path
$obj | Add-Member "Purchased Space" $soft  
$obj | Add-Member "Free Space" $freespace
$obj | Add-Member "Space Used" $usedspace
$obj | Add-Member "Advisory Limit" $advisoryLimit
$emailBody += $obj
##Quick catch if a path does not have an email
if ($line.reportemail){ 
Send-MailMessage -From $EmailFrom -To $line.reportemail -Subject "Isilon Quota Report" -Body ($emailBody | Out-String) -SmtpServer $SMTPServer -Port $SMTPPort
}
}     



