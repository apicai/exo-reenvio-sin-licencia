#Requires -Modules ExchangeOnlineManagement

[CmdletBinding(SupportsShouldProcess)]
param()

. .\constantes.ps1 -WhatIf:$false

Import-Module ExchangeOnlineManagement

if ($CONECTAR_MS) { Connect-ExchangeOnline -ShowBanner:$false }

$buzonesUsuarioConFw = Get-ExoMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -Filter "ForwardingSmtpAddress -like '*$DOMINIO_FW'" -Properties PrimarySmtpAddress

$buzonesUsuarioConFw | ForEach-Object {
  $buzon = $_.PrimarySmtpAddress
  try {
    Set-Mailbox -Identity $buzon -Type Shared -CustomAttribute15 $BUZON_CONVERTIDO -WhatIf:$WhatIfPreference -ErrorAction stop
    Write-Output "${buzon}: convertido a compartido"
  } catch {
    Write-Error "${buzon}: error al procesar buzon - $_"
  }
}

if ($CONECTAR_MS) { Disconnect-ExchangeOnline -Confirm:$false }
