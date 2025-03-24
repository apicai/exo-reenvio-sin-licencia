# Automatización reenvío sin licencia en Exchange Online

Este repositorio te será útil si quieres evitar el coste de mantener licencias para aquellos usuarios de tu instancia de Exchange Online que no utilicen para nada el servicio ya que tienen configurado el reenvío a otro correo en un proveedor y dominio diferente. También te será útil si un subconjunto de tus usuarios migran su correo a otro proveedor y dominio, y se deban reenviar sus correos a su nueva dirección durante un tiempo para garantizarles una transición razonable.

## Procedimiento

Los buzones personales se convertirán en buzones compartidos que no requieren licencia. **Dichos buzones deben tener ya configurado el reenvío al nuevo correo para que los scripts detecten qué buzones convertir**. El procedimiento se caracteriza por:

- No necesitar listados de buzones a convertir: basta con indicar el dominio del correo que tienen configurado en el reenvío
- Estar dividido en scripts con pasos opcionales en función de las necesidades particulares de cada tenant M365
- Reducir el tamaño de los buzones si fuera necesario para poder convertirlos a compartidos (que tienen un tamaño máximo de 50 Gb)
- Desasignar las licencias tanto heredadas como asignadas individualmente a los buzones una vez convertidos
- Volcar a un fichero Excel el estado de los buzones tras cada paso
- Poder ejecutarse en modo de prueba (con `-WhatIf`)
- Disponer de marcha atrás de todo el proceso
- Ser idempotente de modo que los scripts se pueden ejecutar repetidamente (o reintentar en caso de fallos) sin efectos indeseados, y alcanzar el mismo resultado que se hubiera obtenido al ejecutarlo de una sola vez

## Requisitos

El procedimiento ha sido probado contra un tenant M365 utilizando:

- PowerShell v7.5.0 (puede ser suficiente con la v5.1)
- Módulo Exchange Online Management v3.7.1 (puede ser suficiente con la v2.0.3)
- Módulo Microsoft Graph v2.24.0 (no valen las v2.25.0 a v2.26.1 [por un error en ellas](https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/3201)) (solo necesario para los scripts opcionales)
- Módulo Import Excel v7.8.10 (opcional)
- Un usuario administrador de Exchange Online en el grupo de roles "Administración de la organización" (para el script principal basta con "Recipient Management")

## Scripts

| Nombre | Descripción | Opcional | Módulos | Permisos |
|---|---|---|---|---|
| [`constantes.ps1`](./scripts/constantes.ps1) | Propiedades comunes de configuración | No | Ninguno | Ninguno |
| [`0-instalar-modulos.ps1`](./scripts/0-instalar-modulos.ps1) | Instala las dependencias necesarias | No | Ninguno | Ninguno |
| [`1-convertir-buzones.ps1`](./scripts/1-convertir-buzones.ps1) | Convierte los buzones a compartidos | No | `ExchangeOnlineManagement v2.0.1+` | Recipient Management |
| [`2-reducir-buzones.ps1`](./scripts/2-reducir-buzones.ps1) | Reduce el tamaño de los buzones | Sí | `ExchangeOnlineManagement v2.0.1+` | Recipient Management + Administración de retención |
| [`3-desasignar-grupo-licencias.ps1`](./scripts/3-desasignar-grupo-licencias.ps1) | Saca del grupo de licencias indicado a los usuarios de los buzones | Sí | `ExchangeOnlineManagement v2.0.1+` + `Microsoft.Graph v2.24.0` | Recipient Management + Microsoft Graph: `User.Read.All` + `Group.ReadWrite.All` |
| [`4-desasignar-licencias.ps1`](./scripts/4-desasignar-licencias.ps1) | Quita la licencia indicada a los usuarios de los buzones | Sí | `ExchangeOnlineManagement v2.0.1+` + `Microsoft.Graph v2.24.0` | Recipient Management + Microsoft Graph: `User.ReadWrite.All` + `Organization.Read.All` |
| [`detalles-buzones.ps1`](./scripts/detalles-buzones.ps1) | Lista los detalles de los buzones con reenvío a procesar | Sí | `ExchangeOnlineManagement v2.0.1+` + `Microsoft.Graph v2.24.0` + `ImportExcel` | Recipient Management + Microsoft Graph: `User.Read.All` + `Organization.Read.All` |
| [`marcha-atras.ps1`](./scripts/marcha-atras.ps1) | Restaura el estado inicial de los buzones | Sí | `ExchangeOnlineManagement v2.0.1+` + `Microsoft.Graph v2.24.0` | Recipient Management + Administración de retención + Microsoft Graph: `User.ReadWrite.All` + `Organization.Read.All` + `Group.ReadWrite.All` |

Los scripts que requieran permisos, **abrirán automáticamente una página en el navegador** para hacer login con un usuario que tenga los permisos necesarios en ExchangeOnlineManagement y otra página para hacer login con un usuario con los permisos necesarios en Microsoft Graph.

### Configuración

El fichero [`constantes.ps1`](./scripts/constantes.ps1) se debe editar y actualizar con el dominio de reenvío configurado en los buzones a procesar. Por ejemplo, si un subconjunto de los usuarios migran su correo a `@subdominio.dominio.com` y `@dominio.com`, basta configurar `DOMINIO_FW` con `dominio.com`. El resto de variables no se deben tocar a menos que se sepa lo que se hace.

## Instalación

Se debe ejecutar [`0-instalar-modulos.ps1`](./scripts/0-instalar-modulos.ps1) para instalar las dependencias necesarias: `ExchangeOnlineManagement`, `Microsoft.Graph` (importante utilizar específicamente la v2.24.0) e `ImportExcel`.

## Detalles de los buzones a procesar

Puedes ejecutar en cualquier momento el script [`detalles-buzones.ps1`](./scripts/detalles-buzones.ps1) para ver los detalles de los buzones objetivo que se procesarán: dirección email del buzón, tipo de buzón, dirección email configurada para el reenvío, política de retención actual, tamaño del buzón en GB y licencias del usuario del buzón. También se generará un fichero Excel con los datos en ese momento. **Es recomendable ejecutar este script tras cada paso del procedimiento** ya que hay algunas operaciones que tardan en consolidarse.

## Conversión a buzones compartidos

El script principal a ejecutar para convertir los buzones objetivo con el reenvío al dominio configurado es [`1-convertir-buzones.ps1`](./scripts/1-convertir-buzones.ps1). Machaca el valor que hubiera en `CustomAttribute15` para marcar sus cambios. Puedes ejecutarlo con `-WhatIf` para ver cuáles se procesarían sin alterar nada.

<video src="https://github.com/apicai/exo-reenvio-sin-licencia/raw/refs/heads/main/videos/1-convertir-buzones.mp4">

## Reducción del tamaño de los buzones (opcional)

Ejecuta [`2-reducir-buzones.ps1`](./scripts/2-reducir-buzones.ps1) para reducir el tamaño de los buzones objetivo en caso de que ocupen más de 50 GB. Se utilizará una política de retención para borrar **⚠️ permanentemente ⚠️** los correos con una antigüedad mayor a 1 año, y se iniciará el asistente para disparar su ejecución (dentro de las próximas 24 horas). Machaca el valor que hubiera en `CustomAttribute14` para guardar la política de retención anterior. Si decidieras no ejecutar este script, aquellos buzones convertidos con mas de 50 GB y sin licencia no reenviarían los correos.

| Parámetro | Descripción | Valor por defecto |
|---|---|---|
| `-GbBuzonesALimpiar` | Tamaño en GB de los buzones a los que aplicar la política de borrado | 49 |
| `-AntiguedadDiasCorreosABorrar` | Antigüedad en días de los correos que se borrarán permanentemente | 366 |
| `-ReglasNecesarias` | Nombres de las reglas (ya existentes en tu EXO) que necesites añadir a estos buzones para su mantenimiento | Ninguno |
| `-WhatIf` | Soporte parcial al modo de prueba ya que el script siempre crea la regla y la política de borrado aunque no la aplica a los buzones | Ninguno |



## Desasignación de grupo de licencias (opcional)

Ejecuta [`3-desasignar-grupo-licencias.ps1`](./scripts/3-desasignar-grupo-licencias.ps1) si en tu tenant de M365 la licencia se asignó a los usuarios de los buzones objetivo utilizando un grupo de licencias (deberás consultar su nombre en la administración de licencias). Machaca el valor que hubiera en `CustomAttribute13` para guardar el ID del grupo al que pertenecía. Si no ejecutaras este script, deberás desasignar las licencias de los buzones compartidos por otro medio para conseguir el ahorro.

| Parámetro | Descripción | Obligatorio |
|---|---|---|
| `-NombreGrupoLicencias` | Nombre del grupo de licencias del que sacar a los usuarios de los buzones a procesar | Sí |
| `-WhatIf` | Para probar el funcionamiento sin realmente sacar a los usuarios del grupo de licencias | No |



## Desasignación de licencia (opcional)

Ejecuta [`4-desasignar-licencias.ps1`](./scripts/4-desasignar-licencias.ps1) si en tu tenant de M365 la licencia se asignó de forma individual a cada usuario de los buzones objetivo. Deberás indicar el nombre de la licencia (SkuPartNumber) que puedes consultar con el script de `detalles-buzones.ps1`. Machaca el valor que hubiera en `CustomAttribute12` para guardar la licencia que tenía. Si no ejecutaras este script, deberás desasignar las licencias de los buzones compartidos por otro medio para conseguir el ahorro.

| Parámetro | Descripción | Obligatorio |
|---|---|---|
| `-NombreLicencia` | Nombre de la licencia a desasignar a los usuarios de los buzones a procesar | Sí |
| `-WhatIf` | Para probar el funcionamiento sin realmente alterar las licencias de los usuarios | No |



## Marcha atrás

Ejecuta [`marcha-atras.ps1`](./scripts/marcha-atras.ps1) para deshacer los pasos que se hubieran ejecutado y dejar los buzones configurados como inicialmente estaban. Sin embargo, **no se podrán recuperar los correos borrados** si el script de `2-reducir-buzones.ps1` aplicó la política de borrado a algunos de los buzones objetivo. Utiliza los valores guardados en los atributos personalizados de los buzones `CustomAttribute12` a `CustomAttribute15` para restaurar los cambios. Puedes ejecutarlo con `-WhatIf` para ver cuáles se procesarían sin alterar nada.
