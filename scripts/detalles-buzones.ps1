#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph.Users

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(HelpMessage="Muestra todos los buzones en lugar de solo los que tiene el FW configurado")]
  [switch]$All
)

. .\constantes.ps1 -WhatIf:$false

Import-Module ExchangeOnlineManagement
Import-Module -Name Microsoft.Graph.Users -RequiredVersion 2.24.0 -Force

if ($CONECTAR_MS) {
  Connect-ExchangeOnline -ShowBanner:$false
  Connect-MgGraph -Scopes User.Read.All, Organization.Read.All -NoWelcome
}

if ($All) {
  $buzones = Get-ExoMailbox -ResultSize Unlimited -Filter "RecipientTypeDetails -ne 'DiscoveryMailbox'" -Properties PrimarySmtpAddress,ForwardingAddress,ForwardingSmtpAddress,RecipientTypeDetails,RetentionPolicy
} else {
  $buzones = Get-ExoMailbox -ResultSize Unlimited -Filter "ForwardingSmtpAddress -like '*$DOMINIO_FW'" -Properties PrimarySmtpAddress,ForwardingAddress,ForwardingSmtpAddress,RecipientTypeDetails,RetentionPolicy
}

$tabla = $buzones | ForEach-Object {
  $estadisticas = Get-ExoMailboxStatistics -Identity $_.PrimarySmtpAddress -Properties TotalItemSize -ErrorAction SilentlyContinue
  if ($estadisticas) { 
    $gb = [math]::Round(($estadisticas.TotalItemSize.Value.ToBytes() / 1GB), 2) 
  } else { $gb = "?.??" }
  if ($_.ForwardingAddress) { 
    $fw = $_.ForwardingAddress
  } elseif ($_.ForwardingSmtpAddress) { 
    $fw = $_.ForwardingSmtpAddress 
  } else { $fw = "No tiene" }
  $licencias = Get-MgUserLicenseDetail -UserId $_.PrimarySmtpAddress -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SkuPartNumber

  [PSCustomObject]@{
    Email = $_.PrimarySmtpAddress
    Tipo = $_.RecipientTypeDetails
    Politica = $_.RetentionPolicy
    Reenvio = $fw
    Tamano = $gb
    Licencias = if ($licencias) { $licencias } else { "No tiene" }
  }
} 
| Select-Object @{n="Buzón";e={$_.Email}},
                @{n="Tipo";e={$_.Tipo}},
                @{n="Reenvío";e={$_.Reenvio}},
                @{n="Política";e={$_.Politica}},
                @{n="Tamaño GB";e={$_.Tamano}},
                @{n="Licencias";e={$_.Licencias}}

$tabla | Format-Table -AutoSize

if (-not $All) {
  Import-Module ImportExcel
  $fecha = Get-Date -Format "yyyy-MM-dd_HH.mm"
  $fichero = Join-Path (Get-Location) "buzones_fw_${DOMINIO_FW}_${fecha}.xlsx"
  $tabla | Export-Excel -Path $fichero -WorksheetName "Buzones FW" -TableName "Buzones FW" -AutoSize
  Write-Output "Datos exportados a: $fichero"
}

if ($CONECTAR_MS) {
  Disconnect-MgGraph | Out-Null
  Disconnect-ExchangeOnline -Confirm:$false
}