param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Assign", "Remove", "List")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$UserObjectId,

    [Parameter(Mandatory = $false)]
    [string]$RoleTemplateId,

    [Parameter(Mandatory = $false)]
    [string]$RoleName,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedTenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-AzCliJson {
    param([Parameter(Mandatory = $true)][string]$Command)
    $result = Invoke-Expression $Command
    if (-not $result) { return $null }
    return $result | ConvertFrom-Json
}

function Resolve-UserId {
    if ($UserObjectId) { return $UserObjectId }
    if (-not $UserPrincipalName) {
        throw "Provide either -UserObjectId or -UserPrincipalName."
    }
    $user = Invoke-AzCliJson -Command "az ad user show --id `"$UserPrincipalName`" -o json"
    if (-not $user.id) {
        throw "User not found for UPN: $UserPrincipalName"
    }
    return $user.id
}

function Resolve-Role {
    if ($RoleTemplateId) {
        $role = Invoke-AzCliJson -Command "az rest --method GET --url `"https://graph.microsoft.com/v1.0/directoryRoles`" --query `"value[?roleTemplateId=='$RoleTemplateId'] | [0]`" -o json"
        if (-not $role) {
            az rest --method POST --url "https://graph.microsoft.com/v1.0/directoryRoles" --headers "Content-Type=application/json" --body "{`"roleTemplateId`":`"$RoleTemplateId`"}" --output none | Out-Null
            $role = Invoke-AzCliJson -Command "az rest --method GET --url `"https://graph.microsoft.com/v1.0/directoryRoles`" --query `"value[?roleTemplateId=='$RoleTemplateId'] | [0]`" -o json"
        }
        if (-not $role.id) {
            throw "Could not resolve directory role from template ID: $RoleTemplateId"
        }
        return $role
    }

    if ($RoleName) {
        $role = Invoke-AzCliJson -Command "az rest --method GET --url `"https://graph.microsoft.com/v1.0/directoryRoles`" --query `"value[?displayName=='$RoleName'] | [0]`" -o json"
        if (-not $role.id) {
            throw "Could not find active directory role by name: $RoleName. Try using -RoleTemplateId."
        }
        return $role
    }

    throw "Provide either -RoleTemplateId or -RoleName."
}

Write-Host "Validating Azure CLI context..." -ForegroundColor Cyan
$account = Invoke-AzCliJson -Command "az account show -o json"
if (-not $account.tenantId) {
    throw "No Azure CLI login context found. Run: az login"
}

if ($ExpectedTenantId -and $account.tenantId -ne $ExpectedTenantId) {
    throw "Tenant mismatch. Current=$($account.tenantId) Expected=$ExpectedTenantId"
}

Write-Host "Tenant: $($account.tenantId)" -ForegroundColor Green

if ($Action -eq "List") {
    if ($UserPrincipalName -or $UserObjectId) {
        $userId = Resolve-UserId
        Write-Host "Listing directory role memberships for user: $userId" -ForegroundColor Cyan
        az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles" --output json |
            ConvertFrom-Json |
            Select-Object -ExpandProperty value |
            ForEach-Object {
                $role = $_
                $members = az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles/$($role.id)/members" --output json | ConvertFrom-Json
                $match = $members.value | Where-Object { $_.id -eq $userId }
                if ($match) {
                    [PSCustomObject]@{
                        RoleName       = $role.displayName
                        RoleId         = $role.id
                        RoleTemplateId = $role.roleTemplateId
                    }
                }
            } | Format-Table -AutoSize
        exit 0
    }

    Write-Host "Listing active directory roles..." -ForegroundColor Cyan
    az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles" --query "value[].{RoleName:displayName,RoleId:id,RoleTemplateId:roleTemplateId}" -o table
    exit 0
}

$resolvedUserId = Resolve-UserId
$roleInfo = Resolve-Role

if ($Action -eq "Assign") {
    Write-Host "Assigning role '$($roleInfo.displayName)' to user '$resolvedUserId'..." -ForegroundColor Cyan
    az rest --method POST --url "https://graph.microsoft.com/v1.0/directoryRoles/$($roleInfo.id)/members/`$ref" --headers "Content-Type=application/json" --body "{`"@odata.id`":`"https://graph.microsoft.com/v1.0/directoryObjects/$resolvedUserId`"}" --output none | Out-Null
    Write-Host "Assignment complete." -ForegroundColor Green
}
elseif ($Action -eq "Remove") {
    Write-Host "Removing role '$($roleInfo.displayName)' from user '$resolvedUserId'..." -ForegroundColor Yellow
    az rest --method DELETE --url "https://graph.microsoft.com/v1.0/directoryRoles/$($roleInfo.id)/members/$resolvedUserId/`$ref" --output none | Out-Null
    Write-Host "Removal complete." -ForegroundColor Green
}

Write-Host "Current memberships for user: $resolvedUserId" -ForegroundColor Cyan
& $PSCommandPath -Action List -UserObjectId $resolvedUserId -ExpectedTenantId $ExpectedTenantId
