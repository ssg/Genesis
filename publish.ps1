param (
    [Parameter(Mandatory=$true)]
    $apiKey
)
Publish-Module -Path . -NuGetApiKey $apiKey