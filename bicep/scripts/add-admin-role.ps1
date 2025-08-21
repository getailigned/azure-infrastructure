# PowerShell script to add admin role to Azure AD user
# Run this script to grant admin access to the HT-Management application

param(
    [Parameter(Mandatory=$true)]
    [string]$UserEmail,
    
    [Parameter(Mandatory=$false)]
    [string]$RoleType = "Application Administrator"
)

# Install required modules if not already installed
if (!(Get-Module -ListAvailable -Name AzureAD)) {
    Write-Host "Installing AzureAD PowerShell module..." -ForegroundColor Yellow
    Install-Module AzureAD -Force -AllowClobber
}

# Connect to Azure AD
Write-Host "Connecting to Azure AD..." -ForegroundColor Green
try {
    Connect-AzureAD
    Write-Host "Successfully connected to Azure AD" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Azure AD: $($_.Exception.Message)"
    exit 1
}

# Get the user
Write-Host "Looking up user: $UserEmail" -ForegroundColor Blue
try {
    $user = Get-AzureADUser -ObjectId $UserEmail
    Write-Host "Found user: $($user.DisplayName)" -ForegroundColor Green
} catch {
    Write-Error "User not found: $UserEmail"
    exit 1
}

# Get the role definition
Write-Host "Looking up role: $RoleType" -ForegroundColor Blue
try {
    $role = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq $RoleType}
    
    if (!$role) {
        # Enable the role template if it doesn't exist
        Write-Host "Role not found, enabling role template..." -ForegroundColor Yellow
        $roleTemplate = Get-AzureADDirectoryRoleTemplate | Where-Object {$_.DisplayName -eq $RoleType}
        if ($roleTemplate) {
            Enable-AzureADDirectoryRole -RoleTemplateId $roleTemplate.ObjectId
            $role = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq $RoleType}
        }
    }
    
    if ($role) {
        Write-Host "Found role: $($role.DisplayName)" -ForegroundColor Green
    } else {
        Write-Error "Role not found: $RoleType"
        exit 1
    }
} catch {
    Write-Error "Failed to get role: $($_.Exception.Message)"
    exit 1
}

# Check if user already has the role
$existingAssignment = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId | Where-Object {$_.ObjectId -eq $user.ObjectId}

if ($existingAssignment) {
    Write-Host "User already has the $RoleType role" -ForegroundColor Yellow
} else {
    # Assign the role
    Write-Host "Assigning $RoleType role to $UserEmail..." -ForegroundColor Blue
    try {
        Add-AzureADDirectoryRoleMember -ObjectId $role.ObjectId -RefObjectId $user.ObjectId
        Write-Host "Successfully assigned $RoleType role to $UserEmail" -ForegroundColor Green
    } catch {
        Write-Error "Failed to assign role: $($_.Exception.Message)"
        exit 1
    }
}

# Verify the assignment
Write-Host "Verifying role assignment..." -ForegroundColor Blue
$verification = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId | Where-Object {$_.ObjectId -eq $user.ObjectId}

if ($verification) {
    Write-Host "✅ Role assignment verified successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "User Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($user.DisplayName)" -ForegroundColor White
    Write-Host "  Email: $($user.UserPrincipalName)" -ForegroundColor White
    Write-Host "  Role: $($role.DisplayName)" -ForegroundColor White
    Write-Host ""
    Write-Host "The user can now:" -ForegroundColor Yellow
    Write-Host "  ✓ Access admin functionality in HT-Management" -ForegroundColor Green
    Write-Host "  ✓ Impersonate different user roles for testing" -ForegroundColor Green
    Write-Host "  ✓ View admin testing indicators in the dashboard" -ForegroundColor Green
} else {
    Write-Error "Role assignment verification failed"
    exit 1
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Have the user log out and log back into the application" -ForegroundColor White
Write-Host "2. They should see the Role Switcher in the dashboard header" -ForegroundColor White
Write-Host "3. They can now impersonate different roles for testing" -ForegroundColor White
