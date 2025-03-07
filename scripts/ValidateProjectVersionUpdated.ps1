# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

<#
.Synopsis
    Gets the latest production release version of the specified NuGet package.

.Description
    Gets the NuGet package version of latest production release and compares the
    version to the version set in the specified project file. If they match, this
    script will fail and indicate that the version needs to be updated.

.Parameter packageName
    Specifies the package name of the package. For example, 'microsoft.kiota.abstractions'
    is a valid package name.

.Parameter projectPath
    Specifies the path to the project file.
#>

Param(
    [parameter(Mandatory = $true)]
    [string]$packageName,

    [parameter(Mandatory = $true)]
    [string]$projectPath
)

[xml]$xmlDoc = Get-Content $projectPath

$PropertyGroup = $xmlDoc.Project.PropertyGroup | Where-Object -Property Company -eq "Microsoft"
$versionPrefixString = $PropertyGroup.VersionPrefix
if ($PropertyGroup.VersionSuffix) {
    $versionPrefixString = $versionPrefixString + "-" + $PropertyGroup.VersionSuffix
}

if ($null -eq $versionPrefixString -or $versionPrefixString -eq "") {
    $versionPrefixString = $PropertyGroup.Version
}

# System.Version, get the version prefix.
$currentProjectVersion = [System.Management.Automation.SemanticVersion]"$versionPrefixString"

# API is case-sensitive
$packageName = $packageName.ToLower()
$url = "https://api.nuget.org/v3/registration5-gz-semver2/$packageName/index.json"

# Call the NuGet API for the package and get the current published version.
Try {
    $nugetIndex = Invoke-RestMethod -Uri $url -Method Get
}
Catch {
    if ($_.ErrorDetails.Message -and $_.ErrorDetails.Message.Contains("The specified blob does not exist.")) {
        Write-Host "No package exists. You will probably be publishing $packageName for the first time."
        Exit # exit gracefully
    }
    
    Write-Host $_
    Exit 1
}

$currentPublishedVersion = [System.Management.Automation.SemanticVersion]$nugetIndex.items[0].upper

# Validate that the version number has been updated.
if ($currentProjectVersion -le $currentPublishedVersion) {

    Write-Error "The current published version number, $currentPublishedVersion, and the version number `
               in the csproj file, $currentProjectVersion, match. You must increment the version"
}
else {
    Write-Host "Validated that the version has been updated from $currentPublishedVersion to $currentProjectVersion" -ForegroundColor Green
}
