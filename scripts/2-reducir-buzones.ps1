#Requires -Modules ExchangeOnlineManagement

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(HelpMessage="Tamaño de los buzones a procesar, por defecto los de 50 GB o más")]
  [int]$GbBuzonesALimpiar = 49,
  [Parameter(HelpMessage="Antigüedad en días de los correos a borrar, por defecto los de hace más de 1 año")]
  [int]$AntiguedadDiasCorreosABorrar = 366,
  [Parameter(HelpMessage="Reglas de retención adicionales necesarias")]
  [string[]]$ReglasNecesarias = @()
)

. .\constantes.ps1 -WhatIf:$false

Import-Module ExchangeOnlineManagement

$nombrePoliticaRetencion = "${PREFIJO_POLITICA_RETENCION}${DOMINIO_FW}"
$nombreReglaBorrado = "${PREFIJO_REGLA_BORRADO}${AntiguedadDiasCorreosABorrar}"
$ReglasNecesarias += $nombreReglaBorrado

if ($CONECTAR_MS) { Connect-ExchangeOnline -ShowBanner:$false }

try {

  if (-not (Get-RetentionPolicyTag $nombreReglaBorrado -ErrorAction SilentlyContinue)) {
    New-RetentionPolicyTag -Name $nombreReglaBorrado -Type All -AgeLimitForRetention $AntiguedadDiasCorreosABorrar -RetentionAction PermanentlyDelete -Comment "Borra permanentemente los elementos pasados $AntiguedadDiasCorreosABorrar días" -ErrorAction stop | Out-Null
    Write-Output "${nombreReglaBorrado}: regla de retención creada"
  }

  if (-not (Get-RetentionPolicy $nombrePoliticaRetencion -ErrorAction SilentlyContinue)) {
    New-RetentionPolicy -Name $nombrePoliticaRetencion -RetentionPolicyTagLinks $ReglasNecesarias -ErrorAction stop | Out-Null
    Write-Output "${nombrePoliticaRetencion}: política de retencion creada"
  } else {
    Set-RetentionPolicy -Identity $nombrePoliticaRetencion -RetentionPolicyTagLinks $ReglasNecesarias -ErrorAction stop | Out-Null
    Write-Output "${nombrePoliticaRetencion}: política de retencion actualizada"
  }

  $buzonesCompartidosConFw = Get-ExoMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox -Filter "ForwardingSmtpAddress -like '*$DOMINIO_FW'" -Properties PrimarySmtpAddress,RetentionPolicy,CustomAttribute14

  $buzonesCompartidosConFw | ForEach-Object {
    $buzon = $_.PrimarySmtpAddress
    if ($_.RetentionPolicy.StartsWith($PREFIJO_POLITICA_RETENCION)) {
      $anteriorPoliticaRetencion = $_.CustomAttribute14
    } else {
      $anteriorPoliticaRetencion = $_.RetentionPolicy
    }
    try {
      $estadisticas = Get-ExoMailboxStatistics -Identity $buzon -Properties TotalItemSize -ErrorAction stop
      $gb = [math]::Round(($estadisticas.TotalItemSize.Value.ToBytes() / 1GB), 2)
      if ($gb -gt $GbBuzonesALimpiar) {
        Set-Mailbox -Identity $buzon -RetentionPolicy $nombrePoliticaRetencion -CustomAttribute14 $anteriorPoliticaRetencion -WhatIf:$WhatIfPreference -ErrorAction stop
        Start-ManagedFolderAssistant -Identity $buzon -WhatIf:$WhatIfPreference -ErrorAction stop
        Write-Output "${buzon}: aplicadas políticas de borrado"
      }
    } catch {
      Write-Error "${buzon}: error al procesar buzón - $_"
    }
  }

} catch {
  Write-Error "Error al crear políticas de retención - $_"
} finally {
  if ($CONECTAR_MS) { Disconnect-ExchangeOnline -Confirm:$false }
}


