[CmdletBinding(SupportsShouldProcess)]
param()

# ACTUALIZAR con el nombre del dominio de reenvio configurado en los buzones de usuario a procesar
Set-Variable -NAME "DOMINIO_FW" -Value "cambiar.dominio.com" -Option ReadOnly

# Hace que se ejecuten el login y el logout a Microsoft en cada script
Set-Variable -NAME "CONECTAR_MS" -Value $true -Option ReadOnly

# Etiqueta para marcar los buzones de usuario convertidos en el CustomAttribute15 del buzon
Set-Variable -Name "BUZON_CONVERTIDO" -Value "buzon-usuario-convertido" -Option ReadOnly
# Prefijo del nombre de la politica de retencion para los buzones convertidos
Set-Variable -Name "PREFIJO_POLITICA_RETENCION" -Value "buzones-con-fw-a-" -Option ReadOnly
# Prefijo del nombre de la regla de borrado para la politica de retencion de los buzones convertidos
Set-Variable -Name "PREFIJO_REGLA_BORRADO" -Value "borrar-correos-dias-" -Option ReadOnly
