#Requires -Modules ExchangeOnlineManagement, @{ ModuleName="Microsoft.Graph.Users"; ModuleVersion="2.24.0" }

[CmdletBinding(SupportsShouldProcess)]
param()

. .\constantes.ps1 -WhatIf:$false

Import-Module ExchangeOnlineManagement
Import-Module -Name Microsoft.Graph.Users -RequiredVersion 2.24.0 -Force

if ($CONECTAR_MS) {
  Connect-ExchangeOnline -ShowBanner:$false
  Connect-MgGraph -Scopes User.ReadWrite.All, Organization.Read.All, Group.ReadWrite.All -NoWelcome
}

$buzonesCompartidosConFw = Get-ExoMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox -Filter "ForwardingSmtpAddress -like '*$DOMINIO_FW'" -Properties PrimarySmtpAddress,CustomAttribute12,CustomAttribute13,CustomAttribute14,CustomAttribute15

$buzonesCompartidosConFw | ForEach-Object {
  $buzon = $_.PrimarySmtpAddress
  $licenciaAnterior = $_.CustomAttribute12
  $grupoLicenciasAnterior = $_.CustomAttribute13
  $politicaRetencionAnterior = $_.CustomAttribute14
  $buzonUsuarioConvertido = $_.CustomAttribute15
  $usuario = Get-MgUser -Filter "userPrincipalName eq '$buzon'" -Property Id -ErrorAction SilentlyContinue
  if ($usuario) {
    try {
      if ($licenciaAnterior) {
        $licencia = New-Object Microsoft.Graph.PowerShell.Models.MicrosoftGraphAssignedLicense
        $licencia.SkuId = $licenciaAnterior
        Set-MgUserLicense -UserId $usuario.Id -AddLicenses @($licencia) -RemoveLicenses @() -WhatIf:$WhatIfPreference -ErrorAction stop | Out-Null
        $licenciaAnterior = $null
      }
    } catch { }
    try {
      if ($grupoLicenciasAnterior) {
        New-MgGroupMemberByRef -GroupId $grupoLicenciasAnterior -BodyParameter @{
          "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($usuario.Id)"
        } -WhatIf:$WhatIfPreference -ErrorAction stop
        $grupoLicenciasAnterior = $null
      }
    } catch { }
  }
  try {
    if ($politicaRetencionAnterior) {
      Set-Mailbox -Identity $buzon -RetentionPolicy $politicaRetencionAnterior -WhatIf:$WhatIfPreference -ErrorAction stop
      $politicaRetencionAnterior = $null
    }
  } catch { }
  try {
    if ($buzonUsuarioConvertido) {
      Set-Mailbox -Identity $buzon -Type Regular -WhatIf:$WhatIfPreference -ErrorAction stop
      $buzonUsuarioConvertido = $null
    }
  } catch { }

  Set-Mailbox -Identity $buzon -CustomAttribute12 $licenciaAnterior -CustomAttribute13 $grupoLicenciasAnterior -CustomAttribute14 $politicaRetencionAnterior -CustomAttribute15 $buzonUsuarioConvertido -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue

  Write-Output "${buzon}: marcha atrás tipo-buzón: $( $buzonUsuarioConvertido ? '❌' : '✅' ), política-retención: $( $politicaRetencionAnterior ? '❌' : '✅' ), grupo-licencias: $( $grupoLicenciasAnterior ? '❌' : '✅' ), licencias: $( $licenciaAnterior ? '❌' : '✅' )"
}

$politicaRentencionAnterior = "${PREFIJO_POLITICA_RETENCION}${DOMINIO_FW}"
try {
  $politica = Get-RetentionPolicy -Identity $politicaRentencionAnterior -ErrorAction SilentlyContinue
  if ($politica) {
    $reglasRetencion = $politica.RetentionPolicyTagLinks
    Remove-RetentionPolicy -Identity $politicaRentencionAnterior -WhatIf:$WhatIfPreference -ErrorAction stop -Confirm:$false
    Write-Output "${politicaRentencionAnterior}: política de retención borrada"

    foreach ($regla in $reglasRetencion) {
      if ($regla.StartsWith($PREFIJO_REGLA_BORRADO)) {
        Remove-RetentionPolicyTag -Identity $regla -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue -Confirm:$false
        Write-Output "${regla}: regla de retención borrada"
      }
    }
  }
} catch {
  Write-Error "${politicaRentencionAnterior}: error al borrar política de retención - $_"
}

if ($CONECTAR_MS) {
  Disconnect-MgGraph | Out-Null
  Disconnect-ExchangeOnline -Confirm:$false
}