#Requires -Modules ExchangeOnlineManagement, @{ ModuleName="Microsoft.Graph.Users"; ModuleVersion="2.24.0" }

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory=$true, HelpMessage="Nombre de la licencia a desasignar")]
  [ValidateNotNullOrEmpty()]
  [string]$NombreLicencia
)

. .\constantes.ps1 -WhatIf:$false

Import-Module ExchangeOnlineManagement
Import-Module -Name Microsoft.Graph.Users -RequiredVersion 2.24.0 -Force

if ($CONECTAR_MS) {
  Connect-ExchangeOnline -ShowBanner:$false
  Connect-MgGraph -Scopes User.ReadWrite.All, Organization.Read.All -NoWelcome
}

$buzonesCompartidosConFw = Get-ExoMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox -Filter "ForwardingSmtpAddress -like '*$DOMINIO_FW'" -Properties PrimarySmtpAddress

$buzonesCompartidosConFw | ForEach-Object {
  $buzon = $_.PrimarySmtpAddress
  try {
    $usuario = Get-MgUser -Filter "userPrincipalName eq '$buzon'" -Property Id -ErrorAction Stop
    $licencia = Get-MgUserLicenseDetail -UserId $buzon -ErrorAction SilentlyContinue | Where-Object { $_.SkuPartNumber -eq $NombreLicencia } | Select-Object -ExpandProperty SkuId
    if ($licencia) {
      Set-MgUserLicense -UserId $usuario.Id -AddLicenses @() -RemoveLicenses $licencia -WhatIf:$WhatIfPreference -ErrorAction stop | Out-Null
      Set-Mailbox -Identity $buzon -CustomAttribute12 $licencia -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue
      Write-Output "${buzon}: licencia desasignada"
    }
  } catch {
    Write-Error "${buzon}: error al procesar buzon - $_"
  }
}

if ($CONECTAR_MS) {
  Disconnect-MgGraph | Out-Null
  Disconnect-ExchangeOnline -Confirm:$false
}
