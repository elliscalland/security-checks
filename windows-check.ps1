$ErrorActionPreference = "SilentlyContinue"

function Get-DefenderStatus {
    $mp = Get-MpComputerStatus

    if (-not $mp) {
        return @{
            installed = $false
            enabled = $false
            realtime_protection = $false
            signatures_up_to_date = $false
            details = "Microsoft Defender status unavailable"
        }
    }

    return @{
        installed = $true
        enabled = [bool]$mp.AntivirusEnabled
        realtime_protection = [bool]$mp.RealTimeProtectionEnabled
        signatures_up_to_date = -not [bool]$mp.AntivirusSignatureOutOfDate
        antispyware_enabled = [bool]$mp.AntispywareEnabled
        details = "Microsoft Defender checked"
    }
}

function Get-FirewallStatus {
    $profiles = Get-NetFirewallProfile

    return @{
        domain_enabled  = ($profiles | Where-Object Name -eq "Domain").Enabled
        private_enabled = ($profiles | Where-Object Name -eq "Private").Enabled
        public_enabled  = ($profiles | Where-Object Name -eq "Public").Enabled
        all_profiles_enabled = (($profiles | Where-Object Enabled -eq "True").Count -eq 3)
    }
}

function Get-AutoUpdateStatus {
    $au = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -ErrorAction SilentlyContinue
    $auPolicy = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue

    $noAutoUpdate = $null
    $auOptions = $null

    if ($auPolicy) {
        $noAutoUpdate = $auPolicy.NoAutoUpdate
        $auOptions = $auPolicy.AUOptions
    }
    elseif ($au) {
        $noAutoUpdate = $au.NoAutoUpdate
        $auOptions = $au.AUOptions
    }

    $enabled = $true
    if ($noAutoUpdate -eq 1) {
        $enabled = $false
    }

    return @{
        auto_updates_enabled = $enabled
        au_options = $auOptions
        raw_no_auto_update = $noAutoUpdate
    }
}

function Get-OSPatchInfo {
    $os = Get-ComputerInfo
    $hotfix = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1

    return @{
        os_name = $os.WindowsProductName
        os_version = $os.WindowsVersion
        os_build = $os.OsBuildNumber
        last_hotfix_id = $hotfix.HotFixID
        last_hotfix_installed_on = $hotfix.InstalledOn
    }
}

$result = @{
    hostname = $env:COMPUTERNAME
    username = $env:USERNAME
    platform = "windows"
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    antivirus = Get-DefenderStatus
    firewall = Get-FirewallStatus
    updates = Get-AutoUpdateStatus
    patching = Get-OSPatchInfo
}

$result.summary = @{
    compliant_antivirus = (
        $result.antivirus.installed -and
        $result.antivirus.enabled -and
        $result.antivirus.realtime_protection -and
        $result.antivirus.signatures_up_to_date
    )
    compliant_firewall = $result.firewall.all_profiles_enabled
    compliant_auto_updates = $result.updates.auto_updates_enabled
}

$result | ConvertTo-Json -Depth 6
