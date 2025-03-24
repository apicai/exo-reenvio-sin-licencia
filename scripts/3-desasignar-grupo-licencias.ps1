#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph.Users

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory=$true, HelpMessage="Nombre del grupo de licencias del que desasignar al buzon")]
  [ValidateNotNullOrEmpty()]
  [string]$NombreGrupoLicencias
)

. .\constantes.ps1 -WhatIf:$false

Import-Module ExchangeOnlineManagement
Import-Module -Name Microsoft.Graph.Users

if ($CONECTAR_MS) {
  Connect-ExchangeOnline -ShowBanner:$false
  Connect-MgGraph -Scopes User.Read.All, Group.ReadWrite.All -NoWelcome
}

$buzonesCompartidosConFw = Get-ExoMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox -Filter "ForwardingSmtpAddress -like '*$DOMINIO_FW'" -Properties PrimarySmtpAddress

$grupoLicencias = Get-MgGroup -Filter "displayName eq '${NombreGrupoLicencias}'" -ErrorAction SilentlyContinue

if ($grupoLicencias) {
  $buzonesCompartidosConFw | ForEach-Object {
    $buzon = $_.PrimarySmtpAddress
    $anteriorGrupoLicencias = $grupoLicencias.Id
    try {
      $usuario = Get-MgUser -Filter "userPrincipalName eq '$buzon'" -Property Id -ErrorAction Stop
      Remove-MgGroupMemberByRef -GroupId $grupoLicencias.Id -DirectoryObjectId $usuario.Id -WhatIf:$WhatIfPreference -ErrorAction stop
      Set-Mailbox -Identity $buzon -CustomAttribute13 $anteriorGrupoLicencias -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue
      Write-Output "${buzon}: grupo licencias desasignado"
    } catch { }
  }
} else {
  Write-Error "${NombreGrupoLicencias}: grupo de licencias no encontrado"
}

if ($CONECTAR_MS) {
  Disconnect-MgGraph | Out-Null
  Disconnect-ExchangeOnline -Confirm:$false
}
