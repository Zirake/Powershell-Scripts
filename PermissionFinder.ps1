<#
.SYNOPSIS
    The script will go through and recursivly pull all directories and their permissions and lay it in a list of whom has access to what.

.NOTES
    Author : -------------
    Date : 4/4/2022
    Last Updated : 12/5/2022

.PARAMETER -Path
    Provide a folder path of which you'd like to have the permissions pulled.

.PARAMETER -r -Recurse
    Allows the user to do it for the current directory only or all directories underneath.

.PARAMETER -OutputFile
    Put in a full path with the filename.csv and it will output to the file.

.PARAMETER -Display
    If you are using the -OutputFile option, the display with the data will not show. If you want it to write
    to a file and pop up a display of the data, you can use this option.
#>

param
(
    [parameter(Mandatory=$true)]
    [string]$path,

    [Parameter()]
    [alias("-r")]
    [switch]$recurse,

    [Parameter()]
    [string]$OutputFile,

    [Parameter()]
    [switch]$Display
)


function testOutPutFile()
{
    if ((Test-Path -path (Split-Path -path $OutputFile)) -eq $false)
    {
        Write-Host "Sorry, the path doesn't exist, please enter a valid path"
        return $false
    }
    else 
    {
        return $true
    }
}


function FolderPermissionPull($FolderPathArray)
{
    $output = @()
    # Pull the Parent Directory
    $acl = Get-Acl -Path $path
    foreach ($access in $acl.Access)
        {
            $properties = [ordered]@{'Folder name'=$path;'Group/User'=$access.IdentityReference;'Permissions'=$access.FileSystemRights;'Inherited'=$access.IsInherited}
            $output += New-Object -TypeName PSObject -Property $properties
        }
    # Traverse each folder looking for each permission.
    foreach ($Folder in $FolderPathArray)
    {
        $acl = Get-Acl -Path $Folder.FullName

        # Grab every property and divide it up by each member in the permission.
        foreach ($access in $acl.Access)
        {
            $properties = [ordered]@{'Folder name'=$Folder.FullName;'Group/User'=$access.IdentityReference;'Permissions'=$access.FileSystemRights;'Inherited'=$access.IsInherited}
            $output += New-Object -TypeName PSObject -Property $properties
        }
    }
    return $output
}

# Test to make sure output file is valid before processing anything
if(![string]::IsNullOrEmpty($OutputFile))
{
    $pathExist = testOutPutFile
    if ($pathExist -eq $false)
    {
        exit
    }
}

# If it's recursive, return all folder below and it's parent directory.
if($recurse.IsPresent)
{
    $FolderPathArray = Get-ChildItem -Directory -Path $path -Recurse -Force
    $output = FolderPermissionPull($FolderPathArray)
}
# Otherwise return only the directory listed and it's parent.
else 
{
    $FolderPathArray = Get-ChildItem -Directory -Path $path -Force
    $output = FolderPermissionPull($FolderPathArray)
}

# Write Output to file
if(![string]::IsNullOrEmpty($OutputFile))
{
    if($Display.IsPresent)
    {
        $output | Out-GridView
    }
    $output | Export-Csv $OutputFile -NoType
    $FileMessageOutput = "and successfully written to $OutputFile"
}
else
{
    $output | Out-GridView
}

Write-Host "Process completed" $FileMessageOutput