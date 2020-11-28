<#
This is for testing during development only. It shouldn't be deployed or used by anyone anyway.
#>

#requires -RunAsAdministrator
#requires -Version 5.0

Import-Module .\Genesis.psd1
try {
    Update-SystemConfiguration $env:OneDrive\dev\SSG.yaml -Verbose
}
finally {
    Remove-Module Genesis
}