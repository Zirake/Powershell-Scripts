<#
.SYNOPSIS
    This will allow you to enable or disable Hyper-v
.Notes
    Author : --------------
    Date : 10/18/2022
    Last Updated : 10/18/22
.Parameter -Enable
    This will enable Hyper-V and request user to reboot
.Parameter -Disable
    This will disable Hyper-V and request user to reboot
#>

param
(
    [CmdLetBinding()]
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

# Main

if($Enable.IsPresent -and !($Disable.IsPresent))
{
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor
    exit
}

if($Disable.IsPresent -and !($Enable.IsPresent))
{
    Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor
    exit
}

else 
{
    Write-Host "One switch must be used, no more no less." -fore Red
}

#End Main
