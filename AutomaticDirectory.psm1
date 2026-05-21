<#
.SYNOPSIS
    AD Installation Module - Provides functions to install and configure Active Directory Domain Services.

.DESCRIPTION
    Contains functions to:
        - Install AD DS
        - Create a new forest domain controller
        - Add a domain controller to an existing domain

.AUTHOR
    nlence-l & faventur

.VERSION
    1.0

.COMPANYNAME
    42

.NOTES
    Created: 2026-05-15
    Tested on: Windows Server 2025
#>

# ==========================
# AD Installation Functions
# ==========================

function Install-ADPackage {
<#
.SYNOPSIS
    Installs Active Directory and required dependencies for the Domain Controller role.

.DESCRIPTION
    Installs the necessary Windows features for Active Directory Domain Services
    and supporting components. Prepares the server for promotion to a Domain Controller.

.EXAMPLE
    Install-ADPackage
    # Installs AD DS and required components on the current server

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
    Ensure the server has administrative privileges and network connectivity
#>

    if (-not (Get-WindowsFeature AD-Domain-Services).Installed) {
        try {
            Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        } catch {
            Write-Error "Failed to install Active Directory Domain Services: $_"
        }
    } else {
        Write-Host "Active Directory Domain Services is already installed."
    }

    Write-Verbose "Active Directory Domain Services installed successfully."
}


function New-ForestDomainController {
<#
.SYNOPSIS
    Promotes the server to a new forest Domain Controller.

.DESCRIPTION
    Creates a new Active Directory forest on the server, initializing
    the domain with the specified domain name and NetBIOS name. Handles
    prerequisite checks and prepares the server for forest creation.

.PARAMETER DomainAddress
    The fully qualified domain name (FQDN) for the new forest (e.g., "mydomain.com").

.PARAMETER NetBiosName
    The NetBIOS name to assign to the new forest (e.g., "MYDOMAIN").

.EXAMPLE
    New-ForestDomainController -DomainAddress "mydomain.com" -NetBiosName "MYDOMAIN"
    # Creates a new forest called "mydomain.com" with the NetBIOS name "MYDOMAIN".

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
    Ensure the server has a static IP address and meets all Active Directory
    requirements before running this function
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$DomainAddress,

        [Parameter(Mandatory=$true)]
        [string]$NetBiosName
    )

    if (-not (Get-Module ADDSDeployment)) {
        Import-Module ADDSDeployment
    }

    try {
        Install-ADDSForest `
        -DomainName $DomainAddress `
        -DomainNetbiosName $NetBiosName `
        -ForestMode "WinThreshold" `
        -DomainMode "WinThreshold" `
        -InstallDNS:$true `
        -SafeModeAdministratorPassword (Read-Host -Prompt "DSRM Password:" -AsSecureString) `
        -Force:$true
    } catch {
        Write-Error "Failed to create the forest: $_"
    }

    Write-Verbose "New Active Directory forest created successfully."
}

function Add-DomainController {
<#
.SYNOPSIS
    Promotes the server to a Domain Controller by joining an existing Active Directory domain.

.DESCRIPTION
    Configures the server as an additional Domain Controller in an existing
    Active Directory domain. Handles all necessary checks and preparations before promotion.

.PARAMETER DomainAddress
    The fully qualified domain name (FQDN) of the existing domain to join.

.EXAMPLE
    Add-DomainController -DomainAddress "existingdomain.com"
    # Promotes the current server to a Domain Controller in the "existingdomain.com" domain.

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
    Ensure the server has network connectivity to the existing domain controller
    and appropriate credentials are available
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$DomainAddress
    )

    if (-not (Get-Module ADDSDeployment)) {
        Import-Module ADDSDeployment
    }

    try {
        Install-ADDSDomainController `
        -DomainName $DomainAddress `
        -Credential (Get-Credential) `
        -InstallDNS `
        -SafeModeAdministratorPassword (Read-Host -Prompt "DSRM Password:" -AsSecureString)
    } catch {
        Write-Error "Failed to add the domain controller to the existing Active Directory domain."
    }

    Write-Verbose "Domain Controller added successfully."
}

# ===================
# Data Base Functions
# ====================

function Save-ADDatabase {
<#
.SYNOPSIS
    Exports Active Directory users and groups into a CSV database file.

.DESCRIPTION
    Retrieves users and groups from the Active Directory domain and exports
    the selected properties into a CSV file. Allows the administrator to
    define a custom delimiter and specify which attributes should be included
    in the exported database.

.PARAMETER Path
    The destination path where the CSV database file will be saved.

.PARAMETER Delimiter
    The delimiter character used in the CSV export file.

.PARAMETER Properties
    An undefined number of Active Directory attributes to include
    in the exported database.

.EXAMPLE
    Export-ADDatabase `
        -Path "C:\Backup\ad_database.csv" `
        -Delimiter ";" `
        -Properties "Name","SamAccountName","Mail"

    # Exports Active Directory users and groups into a CSV file
    # using ";" as the delimiter and including the selected properties.

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
    Ensure the ActiveDirectory module is installed and imported before
    running this function.
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Delimiter,

        [Parameter(Mandatory=$false)]
        [string[]]$Properties

    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # If no properties are provided, use default properties
        if (-not $Properties) {
            $Properties = @(
                "Name",
                "SamAccountName",
                "UserPrincipalName",
                "Mail",
                "Enabled"
            )
        }

        # Retrieve all users from Active Directory
        $Users = Get-ADUser -Filter * -Properties $Properties |
        Select-Object $Properties

        # Retrieve all groups from Active Directory
        $Groups = Get-ADGroup -Filter * -Properties Name |
        Select-Object Name

        # Create a structured export object
        $Database = @()

        foreach ($User in $Users) {
            $Database += [PSCustomObject]@{
                Type = "User"
                Data = ($User | ConvertTo-Json -Compress)
            }
        }

        foreach ($Group in $Groups) {
            $Database += [PSCustomObject]@{
                Type = "Group"
                Data = ($Group | ConvertTo-Json -Compress)
            }
        }

        # Export the database into a CSV file
        $Database | Export-Csv `
            -Path $Path `
            -Delimiter $Delimiter `
            -NoTypeInformation `
            -Encoding UTF8

        Write-Host "Active Directory database exported successfully to: $Path"

    } catch {
        Write-Error "Failed to export the Active Directory database: $_"
    }



}

function Import-ADDatabase {
<#
.SYNOPSIS
    Imports an Active Directory database from a CSV file.

.DESCRIPTION
    Loads a previously exported CSV database file containing Active Directory
    users and groups information. Parses the file using the specified delimiter
    and restores or processes the imported data for further Active Directory
    operations.

.PARAMETER Path
    The path to the CSV database file to import.

.PARAMETER Delimiter
    The delimiter character used in the CSV file.

.EXAMPLE
    Import-ADDatabase `
        -Path "C:\Backup\ad_database.csv" `
        -Delimiter ";"

    # Imports the Active Directory database from the specified CSV file.

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
    Ensure the specified CSV file exists and is accessible before
    running this function.
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Delimiter
    )

        if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the CSV file exists
        if (-not (Test-Path $Path)) {
            throw "The specified file does not exist."
        }

        # Import the CSV database
        $Database = Import-Csv `
            -Path $Path `
            -Delimiter $Delimiter

        $DomainName = (Get-ADDomain).DNSRoot

        foreach ($Entry in $Database) {

            $UserPrincipalName = "$($Entry.SamAccountName)@$DomainName"
            $EmailAddress = "$($Entry.SamAccountName)@$DomainName"

            # Check if the user already exists
            if (-not (Get-ADUser -Filter "SamAccountName -eq '$($Entry.SamAccountName)'" -ErrorAction SilentlyContinue)) {

                New-ADUser `
                    -Name $Entry.Name `
                    -SamAccountName $Entry.SamAccountName `
                    -UserPrincipalName $UserPrincipalName `
                    -EmailAddress $EmailAddress `
                    -Path $Entry.OU `
                    -Enabled $true `
                    -AccountPassword (ConvertTo-SecureString "TotalyN0tSecure*" -AsPlainText -Force) `
                    -ChangePasswordAtLogon $true

                Write-Host "User created: $($Entry.SamAccountName)"
            }

            # Check if the group already exists
            if (-not (Get-ADGroup -Filter "Name -eq '$($Entry.Group)'" -ErrorAction SilentlyContinue)) {

                New-ADGroup `
                    -Name $Entry.Group `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $Entry.OU

                Write-Host "Group created: $($Entry.Group)"
            }

            # Add the user to the group
            Add-ADGroupMember -Identity $Entry.Group -Members $Entry.SamAccountName
            Write-Host "User '$($Entry.SamAccountName)' added to group '$($Entry.Group)'."
        }

        Write-Host "Active Directory database imported successfully."

    } catch {
        Write-Error "Failed to import the Active Directory database: $_"
    }
}

# ===============
# User Functions
# ===============

function New-ADUserAccount {
<#
.SYNOPSIS
    Creates a new Active Directory user account.

.DESCRIPTION
    Creates a new user in Active Directory using the provided
    account information, organizational unit, and group assignment.
    Automatically generates the UserPrincipalName and email address
    based on the domain configuration.

.PARAMETER AccountName
    The username of the new Active Directory account.

.PARAMETER OrganizationalUnit
    The Organizational Unit (OU) where the user account will be created.

.PARAMETER GroupName
    The group to which the user will be added after creation.

.EXAMPLE
    New-ADUserAccount `
        -AccountName "jdoe" `
        -OrganizationalUnit "MyExistingOU" `
        -GroupName "Employees"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
    The default password must be changed at first logon.
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccountName,

        [Parameter(Mandatory=$true)]
        [string]$UserOU,

        [Parameter(Mandatory=$false)]
        [string]$GroupOU,

        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )

    # Guard: check if running elevated
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This function requires an elevated PowerShell session. Please re-run as Administrator."
        return
    }

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Check if the user already exists
        if (Get-ADUser -Filter "SamAccountName -eq '$AccountName'" -ErrorAction SilentlyContinue) {
            throw "The user '$AccountName' already exists."
        }
        
        # Check if the user OU exists and store it
        $UserOUObject = Get-ADOrganizationalUnit -LDAPFilter "(name=$UserOU)" -ErrorAction SilentlyContinue
        if (-not $UserOUObject) {
            throw "The OU '$UserOU' doesn't exist."
        }

        # Check if the group already exists
        $GroupExists = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
        # $GroupExists = Get-ADGroup -LDAPFilter "(cn=$GroupName)" -ErrorAction SilentlyContinue
        
        # Only validate GroupOU if the group doesn't exist
        if (-not $GroupExists) {
            if (-not $GroupOU) {
                throw "GroupOU parameter is required when the group '$GroupName' does not exist."
            }
            $GroupOUObject = Get-ADOrganizationalUnit -LDAPFilter "(name=$GroupOU)" -ErrorAction SilentlyContinue
            if (-not $GroupOUObject) {
                throw "The OU '$GroupOU' doesn't exist."
            }
        }

        # Retrieve domain information
        $Domain = Get-ADDomain
        $DomainName = $Domain.DNSRoot

        # Generate user information
        $UserPrincipalName = "$AccountName@$DomainName"
        $EmailAddress = "$AccountName@$DomainName"

        # Default password
        $Password = ConvertTo-SecureString "TotalyN0tSecure" -AsPlainText -Force        

        # Create the Active Directory user
        New-ADUser `
            -Name               $AccountName `
            -SamAccountName     $AccountName `
            -UserPrincipalName  $UserPrincipalName `
            -EmailAddress       $EmailAddress `
            -Path               $UserOUObject.DistinguishedName `
            -AccountPassword    $Password `
            -Enabled            $true `
            -ChangePasswordAtLogon $true

        if ($GroupExists) {
            Add-ADGroupMember -Identity $GroupName -Members $AccountName
        } else {
            New-ADGroup `
                -Name           $GroupName `
                -SamAccountName $GroupName `
                -GroupScope     Global `
                -GroupCategory  Security `
                -Path           $GroupOUObject.DistinguishedName

            Add-ADGroupMember -Identity $GroupName -Members $AccountName
        }

        Write-Host "User '$AccountName' created successfully."

    } catch {
        Write-Error "Failed to create the user: $_"
    }
}

function Reset-ADUserPassword {
<#
.SYNOPSIS
    Resets the password of an Active Directory user account.

.DESCRIPTION
    Resets the password of the specified Active Directory user
    and optionally forces the user to change the password at
    the next logon.

.PARAMETER AccountName
    The username of the Active Directory account.

.EXAMPLE
    Reset-ADUserPassword -AccountName "jdoe"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccountName
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the user exists
        $User = Get-ADUser `
            -Filter "SamAccountName -eq '$AccountName'" `
            -ErrorAction SilentlyContinue

        if (-not $User) {
            throw "The user '$AccountName' does not exist."
        }

        # Define the new password
        $Password = ConvertTo-SecureString "TotalyN0tSecure" -AsPlainText -Force

        # Reset the password
        Set-ADAccountPassword `
            -Identity $AccountName `
            -NewPassword $Password `
            -Reset

        # Force password change at next logon
        Set-ADUser `
            -Identity $AccountName `
            -ChangePasswordAtLogon $true

        Write-Host "Password reset successfully for '$AccountName'."

    } catch {
        Write-Error "Failed to reset the password: $_"
    }
}

function Set-ADUserAttribute {
<#
.SYNOPSIS
    Modifies an attribute of an Active Directory user.

.DESCRIPTION
    Updates a specified Active Directory user attribute
    with a new desired value.

.PARAMETER AccountName
    The username of the Active Directory account.

.PARAMETER AttributeName
    The name of the attribute to modify.

.PARAMETER Value
    The new value assigned to the attribute.

.EXAMPLE
    Set-ADUserAttribute `
        -AccountName "jdoe" `
        -AttributeName "Department" `
        -Value "IT"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccountName,

        [Parameter(Mandatory=$true)]
        [string]$AttributeName,

        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the user exists
        $User = Get-ADUser `
            -Filter "SamAccountName -eq '$AccountName'" `
            -ErrorAction SilentlyContinue

        if (-not $User) {
            throw "The user '$AccountName' does not exist."
        }

        # Modify the user attribute
        Set-ADUser `
            -Identity $AccountName `
            -Replace @{ $AttributeName = $Value }

        Write-Host "Attribute '$AttributeName' updated successfully."

    } catch {
        Write-Error "Failed to update the user attribute: $_"
    }
}

function Get-ADUserInformation {
<#
.SYNOPSIS
    Retrieves information about an Active Directory user.

.DESCRIPTION
    Retrieves one or more attributes from a specified
    Active Directory user account.

.PARAMETER AccountName
    The username of the Active Directory account.

.PARAMETER Properties
    The list of properties to retrieve from the user account.

.EXAMPLE
    Get-ADUserInformation `
        -AccountName "jdoe" `
        -Properties "Mail","Department"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccountName,

        [Parameter(Mandatory=$false)]
        [string[]]$Properties
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # If no properties are provided, retrieve all properties
        if (-not $Properties) {

            Get-ADUser `
                -Identity $AccountName `
                -Properties * |

            Format-List *

        } else {

            Get-ADUser `
                -Identity $AccountName `
                -Properties $Properties |

            Select-Object $Properties
        }

    } catch {
        Write-Error "Failed to retrieve user information: $_"
    }
}

function Get-ADAllUsersInformation {
<#
.SYNOPSIS
    Retrieves information about all Active Directory users.

.DESCRIPTION
    Retrieves one or more attributes from every user
    account in the Active Directory domain.

.PARAMETER Properties
    The list of properties to retrieve from all users.

.EXAMPLE
    Get-ADAllUsersInformation `
        -Properties "Name","Mail","Department"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>
    param (
        [Parameter(Mandatory=$false)]
        [string[]]$Properties
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # If no properties are provided, retrieve all properties
        if (-not $Properties) {

            Get-ADUser `
                -Filter * `
                -Properties * |

            Format-List *

        } else {

            Get-ADUser `
                -Filter * `
                -Properties $Properties |

            Select-Object $Properties
        }

    } catch {
        Write-Error "Failed to retrieve users information: $_"
    }
}

# ================
# Group Functions
# ================

function New-ADSecurityGroup {
<#
.SYNOPSIS
    Creates a new Active Directory security group.

.DESCRIPTION
    Creates a new security group in the specified Organizational Unit
    with the desired scope and description.

.PARAMETER GroupName
    The name of the group to create.

.PARAMETER OrganizationalUnit
    The Organizational Unit (OU) where the group will be created.

.PARAMETER GroupScope
    The scope of the group (Global, DomainLocal, or Universal).

.PARAMETER Description
    A description for the security group.

.EXAMPLE
    New-ADGroup `
        -GroupName "ITAdmins" `
        -OrganizationalUnit "MyExistingOU" `
        -GroupScope "Global" `
        -Description "IT Administrators Group"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,

        [Parameter(Mandatory=$true)]
        [string]$OrganizationalUnit,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Global", "DomainLocal", "Universal")]
        [string]$GroupScope,

        [Parameter(Mandatory=$false)]
        [string]$Description
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify if the group already exists
        if (Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue) {
            throw "The group '$GroupName' already exists."
        }

        # Retrieve domain information
        $Domain = Get-ADDomain
        $DomainDN = $Domain.DistinguishedName

        # Build the full user OU path
        $OUPath = "OU=$OrganizationalUnit,$DomainDN"

        # Create the group
        New-ADGroup `
            -Name $GroupName `
            -GroupScope $GroupScope `
            -GroupCategory Security `
            -Path $OUPath `
            -Description $Description

        Write-Host "Group '$GroupName' created successfully."

    } catch {
        Write-Error "Failed to create the group: $_"
    }
}

function Set-ADGroupAttribute {
<#
.SYNOPSIS
    Modifies an attribute of an Active Directory group.

.DESCRIPTION
    Updates a specified Active Directory group attribute
    with a new desired value.

.PARAMETER GroupName
    The name of the Active Directory group.

.PARAMETER AttributeName
    The name of the attribute to modify.

.PARAMETER Value
    The new value assigned to the attribute.

.EXAMPLE
    Set-ADGroupAttribute `
        -GroupName "ITAdmins" `
        -AttributeName "Description" `
        -Value "Updated IT administrators group"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,

        [Parameter(Mandatory=$true)]
        [string]$AttributeName,

        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the group exists
        $Group = Get-ADGroup `
            -Filter "Name -eq '$GroupName'" `
            -ErrorAction SilentlyContinue

        if (-not $Group) {
            throw "The group '$GroupName' does not exist."
        }

        # Modify the group attribute
        Set-ADGroup `
            -Identity $GroupName `
            -Replace @{ $AttributeName = $Value }

        Write-Host "Group attribute updated successfully."

    } catch {
        Write-Error "Failed to modify the group attribute: $_"
    }
}

function Get-ADGroupMembers {
<#
.SYNOPSIS
    Retrieves all users from an Active Directory group.

.DESCRIPTION
    Returns an exhaustive list of members contained
    in the specified Active Directory group.

.PARAMETER GroupName
    The name of the Active Directory group.

.EXAMPLE
    Get-ADGroupMembers -GroupName "ITAdmins"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the group exists
        $Group = Get-ADGroup `
            -Filter "Name -eq '$GroupName'" `
            -ErrorAction SilentlyContinue

        if (-not $Group) {
            throw "The group '$GroupName' does not exist."
        }

        # Retrieve group members
        Get-ADGroupMember `
            -Identity $GroupName

    } catch {
        Write-Error "Failed to retrieve group members: $_"
    }
}

function New-ADDistributionGroup {
<#
.SYNOPSIS
    Creates a new Active Directory distribution group.

.DESCRIPTION
    Creates a distribution group used for email distribution
    to multiple users at once.

.PARAMETER GroupName
    The name of the distribution group.

.PARAMETER OrganizationalUnit
    The Organizational Unit (OU) where the group will be created.

.PARAMETER GroupScope
    The scope of the group (Global, DomainLocal, or Universal).

.PARAMETER Description
    A description for the group.

.EXAMPLE
    New-ADDistributionGroup `
        -GroupName "MarketingMail" `
        -OrganizationalUnit "MyExistingOU" `
        -GroupScope "Global" `
        -Description "Marketing distribution group"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,

        [Parameter(Mandatory=$true)]
        [string]$OrganizationalUnit,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Global", "DomainLocal", "Universal")]
        [string]$GroupScope,

        [Parameter(Mandatory=$false)]
        [string]$Description
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify if the group already exists
        if (Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue) {
            throw "The group '$GroupName' already exists."
        }

        # Check if the OU already exists
        if (-not(Get-ADOrganizationalUnit -Filter "Name -eq '$OrganizationalUnit'" -ErrorAction SilentlyContinue)) {
            throw "The OU '$OrganizationalUnit' doesn't exits."
        }

        # Retrieve domain information
        $Domain = Get-ADDomain
        $DomainDN = $Domain.DistinguishedName

        # Build the full user OU path
        $OUPath = "OU=$OrganizationalUnit,$DomainDN"

        # Create the distribution group
        New-ADGroup `
            -Name $GroupName `
            -GroupScope $GroupScope `
            -GroupCategory Distribution `
            -Path $OUpath `
            -Description $Description

        Write-Host "Distribution group '$GroupName' created successfully."

    } catch {
        Write-Error "Failed to create the distribution group: $_"
    }
}

function Add-ADUserToGroup {
<#
.SYNOPSIS
    Adds a user to an Active Directory group.

.DESCRIPTION
    Adds an existing Active Directory user to the specified group.
    The function blocks the operation if the user or group does not exist.

.PARAMETER AccountName
    The SamAccountName of the Active Directory user.

.PARAMETER GroupName
    The name of the Active Directory group.

.EXAMPLE
    Add-ADUserToGroup `
        -AccountName "jdoe" `
        -GroupName "ITAdmins"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$AccountName,

        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the user exists
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$AccountName'" -ErrorAction SilentlyContinue)) {
            throw "The user '$AccountName' does not exist."
        }

        # Verify that the group exists
        if (-not (Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue)) {
            throw "The group '$GroupName' does not exist."
        }

        # Add the user to the group
        Add-ADGroupMember `
            -Identity $GroupName `
            -Members $AccountName

        Write-Host "User '$AccountName' added to '$GroupName'."

    } catch {
        Write-Error "Failed to add the user to the group: $_"
    }
}

function Remove-ADUserFromGroup {
<#
.SYNOPSIS
    Removes a user from an Active Directory group.

.DESCRIPTION
    Removes an existing Active Directory user from the specified group.
    The function blocks the operation if the user does not exist
    or is not a member of the group.

.PARAMETER AccountName
    The SamAccountName of the Active Directory user.

.PARAMETER GroupName
    The name of the Active Directory group.

.EXAMPLE
    Remove-ADUserFromGroup `
        -AccountName "jdoe" `
        -GroupName "ITAdmins"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$AccountName,

        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that the user exists
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$AccountName'" -ErrorAction SilentlyContinue)) {
            throw "The user '$AccountName' does not exist."
        }

        # Verify that the group exists
        if (-not (Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue)) {
            throw "The group '$GroupName' does not exist."
        }

        # Verify membership
        $Members = Get-ADGroupMember -Identity $GroupName

        if ($Members.SamAccountName -notcontains $AccountName) {
            throw "The user '$AccountName' is not a member of '$GroupName'."
        }

        # Remove the user from the group
        Remove-ADGroupMember `
            -Identity $GroupName `
            -Members $AccountName `
            -Confirm:$false

        Write-Host "User '$AccountName' removed from '$GroupName'."

    } catch {
        Write-Error "Failed to remove the user from the group: $_"
    }
}

function Import-ADGroupMembers {
<#
.SYNOPSIS
    Imports all members from one group into another group.

.DESCRIPTION
    Copies all members from the origin group
    and adds them into the destination group.

.PARAMETER SourceGroupName
    The name of the source group.

.PARAMETER DestinationGroupName
    The name of the destination group.

.EXAMPLE
    Import-ADGroupMembers `
        -SourceGroupName "Developers" `
        -DestinationGroupName "ITAdmins"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$SourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]$DestinationGroupName
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        # Verify that both groups exist
        if (-not (Get-ADGroup -Filter "Name -eq '$SourceGroupName'" -ErrorAction SilentlyContinue)) {
            throw "The source group '$SourceGroupName' does not exist."
        }

        if (-not (Get-ADGroup -Filter "Name -eq '$DestinationGroupName'" -ErrorAction SilentlyContinue)) {
            throw "The destination group '$DestinationGroupName' does not exist."
        }

        # Retrieve members from the source group
        $Members = Get-ADGroupMember `
            -Identity $SourceGroupName

        # Import members into the destination group
        foreach ($Member in $Members) {

            Add-ADGroupMember `
                -Identity $DestinationGroupName `
                -Members $Member
        }

        Write-Host "Members imported successfully."

    } catch {
        Write-Error "Failed to import group members: $_"
    }
}

function Get-ADGroupInformation {
<#
.SYNOPSIS
    Retrieves information about an Active Directory group.

.DESCRIPTION
    Retrieves one or more attributes from the specified
    Active Directory group.

.PARAMETER GroupName
    The name of the Active Directory group.

.PARAMETER Properties
    Optional list of properties to retrieve.

.EXAMPLE
    Get-ADGroupInformation `
        -GroupName "ITAdmins" `
        -Properties "Description","GroupScope"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,

        [Parameter(Mandatory=$false)]
        [string[]]$Properties
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        if (-not $Properties) {

            Get-ADGroup `
                -Identity $GroupName `
                -Properties * | Format-List *

        } else {

            Get-ADGroup `
                -Identity $GroupName `
                -Properties $Properties | Select-Object $Properties
        }

    } catch {
        Write-Error "Failed to retrieve group information: $_"
    }
}

function Get-ADEveryGroupInformation {
<#
.SYNOPSIS
    Retrieves information from every Active Directory group.

.DESCRIPTION
    Retrieves one or more attributes from all groups
    in the Active Directory domain.

.PARAMETER Properties
    Optional list of properties to retrieve.

.EXAMPLE
    Get-ADEveryGroupInformation `
        -Properties "Name","Description"

.NOTES
    Author: nlence-l & faventur
    Date: 2026-05-15
#>

    param (
        [Parameter(Mandatory=$false)]
        [string[]]$Properties
    )

    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }

    try {

        if (-not $Properties) {

            Get-ADGroup `
                -Filter * `
                -Properties * |

            Format-List *

        } else {

            Get-ADGroup `
                -Filter * `
                -Properties $Properties |

            Select-Object $Properties
        }

    } catch {
        Write-Error "Failed to retrieve groups information: $_"
    }
}


Export-ModuleMember -Function Install-ADPackage, New-ForestDomainController, Add-DomainController,
Save-ADDatabase, Import-ADDatabase,
New-ADUserAccount, Reset-ADUserPassword, Set-ADUserAttribute, Get-ADUserInformation, Get-ADAllUsersInformation,
New-ADSecurityGroup, Set-ADGroupAttribute, Get-ADGroupMembers, New-ADDistributionGroup, Add-ADUserToGroup, Remove-ADUserFromGroup, Import-ADGroupMembers, Get-ADGroupInformation, Get-ADEveryGroupInformation
