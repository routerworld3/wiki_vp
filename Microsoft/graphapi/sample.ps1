# === Step 0: Install & Import Graph Module ===
Install-Module Microsoft.Graph.Beta -Scope CurrentUser -Force -ErrorAction SilentlyContinue

# Import only required submodules to avoid exceeding function limits
Import-Module Microsoft.Graph.Beta.Users

#Import-Module Microsoft.Graph.Beta

# === Step 1: Authentication Variables ===
$ClientID    = "FAKE_39b"
$TenantID    = "FAKE_78b"
$ClientSecret = "FAKEc2K"

# Secure the secret and create a credential object
$secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$appCred = New-Object System.Management.Automation.PSCredential($ClientID, $secureSecret)

# Connect to Graph with beta SDK
#Connect-MgGraph -TenantId $TenantID -ClientSecretCredential $appCred -UseBeta

Connect-MgGraph -TenantId $TenantID -ClientSecretCredential $appCred 

# === Step 2: Get Users with CertificateUserIds ===
$users = Get-MgBetaUser -All -Property "displayName", "authorizationInfo", "employeeId"

# Filter and extract 16-digit number
$filtered = $users | Where-Object {
    $_.AuthorizationInfo.CertificateUserIds -match 'X509:<PN>\d{16}@mil'
} | ForEach-Object {
    $user = $_
    $certId = $user.AuthorizationInfo.CertificateUserIds | Where-Object { $_ -match 'X509:<PN>\d{16}@com' }

    if ($certId -match 'X509:<PN>(\d{16})@mil') {
        $number = $matches[1]
    }

    [PSCustomObject]@{
        DisplayName         = $user.DisplayName
        UserId              = $user.Id
        CertificateUserId   = $certId
        ExtractedNumber     = $number
        PreviousEmployeeId  = $user.EmployeeId
    }
}

# === Step 3: Export to Timestamped CSV ===
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvFile   = "UsersWithCertId-$timestamp.csv"

$filtered | Export-Csv $csvFile -NoTypeInformation
Write-Host "`n Exported results to: $csvFile`n"

# === Step 4: Update employeeId ===
foreach ($user in $filtered) {
    $empId = "$($user.ExtractedNumber)"  # Force string

    Write-Host "Updating employeeId for: $($user.DisplayName) → $empId"

    try {
        Update-MgBetaUser -UserId $user.UserId -BodyParameter @{
            employeeId = $empId
        }
        Write-Host " Successfully updated $($user.DisplayName)`n"
    }
    catch {
        Write-Warning " Failed to update $($user.DisplayName): $_"
    }
}
