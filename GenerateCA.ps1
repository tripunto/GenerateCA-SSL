###### Configuracion del script, descomentar y editar
## Si se descomentan, el programa solicitara introducir los datos manualmente
## $CA_Name = "ejemplo.com"
## $CA_Path = "C:\CerCA"
## $CA_File = "RootCA.cer"
## $CA_Pass = "password"
## $CA_Device = "ejemplo.local"
## $CA_Install = $false
###### Fin  de las lineas de  configuración


###### Inicio del programa
echo "Iniciando script PowerShell"


###### Comprueba que esten configuradas las variables o solicita que las introduzca el usuario
if( $CA_Name -eq $null ){ $CA_Name = Read-Host "Introduce el nombre de dominiio CN para el certificado" }
if( $CA_Path -eq $null ){ $CA_Path = Read-Host "Introduce la ruta donde crear los certificados" }
if( $CA_File -eq $null ){ $CA_File = "$CA_Name (RootCA).cer" }
if( $CA_Pass -eq $null ){ $CA_Pass = Read-Host "Introduce la llave de encriptacion" -AsSecureString }
if( $CA_Device -eq $null ){ $CA_Device = Read-Host "Introduce el nombre del dispositivo host" }


###### Remplaza caracteres del nombre del certificado
$CA_File = $CA_File.Replace(":", "-").Replace(" ", "_")


###### Obtiene la ruta actual donde se ejecuta el programa
$OutputPath = Convert-Path .


###### Comprueba si el programa esta en la ruta donde crear los certificados,
###### Crea la ruta de ser necesario y entra en ella para crear los certificados
if( $CA_Path -ne $OutputPath ){ if ( test-path -path $CA_path ){ cd $CA_Path } else { New-Item $CA_Path -itemType Directory ; cd $CA_Path } }
$OutputPath = Convert-Path .\\
$OutputPathCA = $OutputPath + $CA_File

echo $OutputPathCA


##### Comprueba y/o crea el Certificado de Autorización RootCA
if (test-path -path $OutputPathCA){ echo "el archivo $OutputPathCA ya existe" } else {
$Subject = "CN="+$CA_Name
$rootCA = New-SelfSignedCertificate -certstorelocation cert:\currentuser\my -Subject $Subject -HashAlgorithm "SHA512" -KeyUsage CertSign,CRLSign
$rootCAFile = Export-Certificate -Cert $rootCA -FilePath $OutputPathCA
}


##### Importa el certificado de autorizacion (CerCA) para crear el certificado para el cliente (CerSSL)
$rootCA = Import-Certificate -FilePath $OutputPathCA -CertStoreLocation Cert:\CurrentUser\My\


##### Crea el certificado SSL para el dispositivo, firmado por el certificado de autorizacion
$CA_DeviceClean = $CA_Device.Replace(":", "-").Replace(" ", "_")
$FilePath = $OutputPath + $CA_DeviceClean + ".pfx"
$Subject = "CN="+$CA_Device
$cert = New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -Subject $Subject -DnsName $CA_Device -Signer $rootCA -HashAlgorithm "SHA512"
$certFile = Export-PfxCertificate -cert $cert -FilePath $FilePath -Password (ConvertTo-SecureString -String $CA_Pass -Force -AsPlainText)


##### Instalación del certificado en el equipo con sistema operativo Windows
if( $CA_Install -ne $true,$false ){ $Install = Read-Host -Prompt "¿Desea instalar el certificado? Introduce Y para confirmar" }
if( $Install -eq 'y'){ $CA_Install = $true } else { $CA_Install = $false }
if ( $CA_Install ){
WebManagement.exe -SetCert $FilePath $CA_Pass

##### Reinicia el WebManagement para activar el nuevo certificado
sc stop webmanagement
sc start webmanagement

echo "el certificado de $CA_Name para el dispositivo $CA_Device se a creado y instalado."
} else { echo "se a creado el certificado de $CA_Name para el dispositivo $CA_Device pero debe ser instalarlo manualmente." }


##### Vacia las variables por si se necesita crear mas certificados
$CA_Name = $null
$CA_Path = $null
$CA_File = $null
$CA_Pass = $null
$CA_Device = $null
$CA_Install = $null


exit
