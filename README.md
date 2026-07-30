# AutomaticDirectory

A PowerShell module to automate Active Directory administration, built as a 42 School project (42 Mulhouse). It reproduces, through scripting, the operations normally done by clicking through the AD graphical interface — installation, domain controller promotion, database backup/restore, and user & group management.

> **Authors:** nlence-l & faventur
> **Version:** 1.0 · **Tested on:** Windows Server 2025

## About

This project is part of a partnership between 42 and Microsoft, introducing PowerShell and Active Directory scripting. The subject asks for a set of standalone `.ps1` scripts, each automating one AD action. This implementation goes a step further and packages everything as a proper PowerShell **module** (`AutomaticDirectory`).

## Why a module instead of standalone scripts

The subject requests one script per action. I chose to expose the same actions as functions inside a single module for a few reasons:

- **No code duplication.** Every script needs the same boilerplate — importing the `ActiveDirectory` module, existence checks, error handling. In a module, that logic lives in one place instead of being copy-pasted across ~20 files.
- **Discoverability and native tooling.** Each function ships with full comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`), so `Get-Help New-ADUserAccount -Full` and tab-completion work out of the box, exactly like real cmdlets.
- **Idiomatic PowerShell.** Verb-Noun function names (`New-ADUserAccount`, `Get-ADGroupMembers`) follow the approved-verb convention and read like the native AD cmdlets they wrap.
- **Composability.** Functions can call each other and be piped together, which is awkward when each action is an isolated script invoked by path.
- **Single import.** `Import-Module AutomaticDirectory` loads the whole toolset at once, versioned through a manifest (`.psd1`), rather than juggling loose files.

Every action from the subject is still fully covered — it's just organised as callable functions rather than separate files.

## Requirements

- Windows Server with the PowerShell environment (PowerShell ISE recommended for editing)
- Administrator privileges (an elevated session)
- The `ActiveDirectory` PowerShell module (installed by `Install-ADPackage`)

## Installation

Place the module folder somewhere on your `$env:PSModulePath`, or import it directly by path:

```powershell
Import-Module .\AutomaticDirectory\AutomaticDirectory.psd1
```

Confirm the functions are loaded:

```powershell
Get-Command -Module AutomaticDirectory
```

## Conventions

- All functions run from an elevated PowerShell terminal.
- Every function is documented with comment-based help — use `Get-Help <FunctionName> -Full`.
- Default user assumptions (per the subject):
  - Mail address & UserPrincipalName: `name@domainName.com`
  - Basic password: `TotalyN0tSecure`, with a forced change at first logon
  - The default password is never stored in clear text beyond the mandatory bootstrap value

## Functions

### AD installation

| Function | Description | Parameters |
|----------|-------------|------------|
| `Install-ADPackage` | Install AD DS and every dependency needed for the domain controller role | None |
| `New-ForestDomainController` | Promote the server to Domain Controller by creating a new forest | `DomainAddress`, `NetBiosName` |
| `Add-DomainController` | Promote the server to Domain Controller by joining an existing domain | `DomainAddress` |

### Database

| Function | Description | Parameters |
|----------|-------------|------------|
| `Save-ADDatabase` | Export every user and group from the Domain Controller into a CSV | `Path`, `Delimiter`, `Properties` (variable set of attributes) |
| `Import-ADDatabase` | Load a database from a saved CSV file | `Path`, `Delimiter` |

### User management

| Function | Description | Parameters |
|----------|-------------|------------|
| `New-ADUserAccount` | Create a user, place it in an OU, and add it to a group (creating the group if needed) | `AccountName`, `UserOU`, `GroupOU`, `GroupName` |
| `Reset-ADUserPassword` | Reset a user's password and force a change at next logon | `AccountName` |
| `Set-ADUserAttribute` | Modify a user attribute and set it to a new value | `AccountName`, `AttributeName`, `Value` |
| `Get-ADUserInformation` | Retrieve information about a user (all properties if none specified) | `AccountName`, `Properties` |
| `Get-ADAllUsersInformation` | Retrieve information from every user in the domain | `Properties` |

### Group management

| Function | Description | Parameters |
|----------|-------------|------------|
| `New-ADSecurityGroup` | Create a new security group | `GroupName`, `OrganizationalUnit`, `GroupScope`, `Description` |
| `Set-ADGroupAttribute` | Edit a group by modifying one attribute | `GroupName`, `AttributeName`, `Value` |
| `Get-ADGroupMembers` | List all members of a group | `GroupName` |
| `New-ADDistributionGroup` | Create a distribution group for emailing multiple users at once | `GroupName`, `OrganizationalUnit`, `GroupScope`, `Description` |
| `Add-ADUserToGroup` | Add a user to a group (blocks unknown users) | `AccountName`, `GroupName` |
| `Remove-ADUserFromGroup` | Remove a user from a group (blocks unknown users or non-members) | `AccountName`, `GroupName` |
| `Import-ADGroupMembers` | Import all members of one group into another | `SourceGroupName`, `DestinationGroupName` |
| `Get-ADGroupInformation` | Retrieve information about a group (all properties if none specified) | `GroupName`, `Properties` |
| `Get-ADEveryGroupInformation` | Retrieve information from every group in the domain | `Properties` |

## Usage examples

```powershell
# Prepare the server and promote it to a new forest
Install-ADPackage
New-ForestDomainController -DomainAddress "mydomain.com" -NetBiosName "MYDOMAIN"

# Create a user and add it to a group
New-ADUserAccount -AccountName "jdoe" -UserOU "Employees" -GroupName "IT" -GroupOU "Groups"

# Back up and restore the directory
Save-ADDatabase -Path "C:\Backup\ad.csv" -Delimiter ";" -Properties "Name","SamAccountName","Members"
Import-ADDatabase -Path "C:\Backup\ad.csv" -Delimiter ";"

# Inspect a group
Get-ADGroupMembers -GroupName "IT"
Get-ADGroupInformation -GroupName "IT" -Properties "Description","GroupScope"
```

Get help on any function:

```powershell
Get-Help New-ADUserAccount -Full
```

## Project structure

```
AutomaticDirectory/
├── AutomaticDirectory.psd1   # Module manifest (metadata, version, exports)
└── AutomaticDirectory.psm1   # Module implementation (all functions)
```

## License

Educational project — 42 Mulhouse.