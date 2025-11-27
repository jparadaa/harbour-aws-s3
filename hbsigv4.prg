/*
 * hbsigv4.prg - AWS Signature Version 4 para Harbour
 * 
 * Implementación para interactuar con Amazon S3 usando AWS Signature V4
 * Soporta operaciones de subida, descarga, eliminación y verificación de objetos
 * 
 * Autor: Proyecto Público
 * Fecha: Noviembre 2025
 * Licencia: MIT
 * 
 * Dependencias:
 *   - hbcurl
 * 
 * Variables de entorno requeridas:
 *   AWS_ACCESS_KEY_ID     - Tu Access Key de AWS
 *   AWS_SECRET_ACCESS_KEY - Tu Secret Key de AWS
 */

// ============================================================================
// GENERACIÓN DE URLs PRESIGNADAS (AWS Signature V4)
// ============================================================================

/*
 * AWS_S3_GeneratePresignedUrl()
 * 
 * Genera una URL presignada para acceder a un objeto en S3
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto (ej: "carpeta/archivo.txt")
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región de AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez de la URL (default: 3600)
 *   cMethod    - Método HTTP: GET, PUT, DELETE, HEAD (default: "GET")
 * 
 * Retorna:
 *   cUrl - URL presignada lista para usar
 * 
 * Ejemplo:
 *   cUrl := AWS_S3_GeneratePresignedUrl("mi-bucket", "datos/reporte.pdf", ;
 *                                       cAccessKey, cSecretKey, "us-east-1", 3600, "GET")
 */

#include "hbcurl.ch"

 FUNCTION AWS_S3_GeneratePresignedUrl( cBucket, cKey, cAccessKey, cSecretKey, ;
                                      cRegion, nExpires, cMethod )
   LOCAL cHost, cUrl, cDateISO, cDateTimeISO
   LOCAL cCredScope, cQuery, cCanReq, cHashReq, cStringToSign
   LOCAL cSignKey, cSignature, cCanQuery
   LOCAL cAlgorithm, cService

   cAlgorithm := "AWS4-HMAC-SHA256"
   cService   := "s3"

   IF nExpires == NIL ; nExpires := 3600 ; ENDIF
   IF cMethod   == NIL ; cMethod   := "GET"  ; ENDIF
   IF Empty(cRegion)   ; cRegion   := "us-east-1" ; ENDIF

   // Timestamp en formato ISO8601 (UTC)
   cDateTimeISO := AWS_SigV4_GetCurrentTimestamp()
   cDateISO     := Left( cDateTimeISO, 8 )

   // Normalizar la key (debe empezar con /)
   IF Left(cKey,1) != "/" ; cKey := "/" + cKey ; ENDIF
   
   cHost        := cBucket + ".s3.amazonaws.com"
   cCredScope   := cDateISO + "/" + cRegion + "/" + cService + "/aws4_request"

   // Construir query string con parámetros requeridos por AWS
   cQuery := "X-Amz-Algorithm=" + cAlgorithm + ;
             "&X-Amz-Credential=" + cAccessKey + "/" + cCredScope + ;
             "&X-Amz-Date=" + cDateTimeISO + ;
             "&X-Amz-Expires=" + hb_NToS( nExpires ) + ;
             "&X-Amz-SignedHeaders=host"

   cCanQuery := AWS_SigV4_CanonicalQueryString( cQuery )

   // Canonical Request según especificación AWS Signature V4
   cCanReq := Upper(cMethod) + hb_BChar(10) + ;
              AWS_SigV4_CanonicalURI( cKey ) + hb_BChar(10) + ;
              cCanQuery + hb_BChar(10) + ;
              "host:" + cHost + hb_BChar(10) + ;
              hb_BChar(10) + ;
              "host" + hb_BChar(10) + ;
              "UNSIGNED-PAYLOAD"

   cHashReq      := Lower( HB_SHA256( cCanReq ) )
   
   // String to Sign
   cStringToSign := cAlgorithm + hb_BChar(10) + ;
                    cDateTimeISO + hb_BChar(10) + ;
                    cCredScope + hb_BChar(10) + ;
                    cHashReq

   // Derivación de la signing key: 4 HMACs encadenados
   // Nota: HB_HMAC_SHA256 devuelve hex, convertimos a binario para siguiente HMAC
   cSignKey := hb_HexToStr( HB_HMAC_SHA256( cDateISO, "AWS4" + cSecretKey ) )
   cSignKey := hb_HexToStr( HB_HMAC_SHA256( cRegion, cSignKey ) )
   cSignKey := hb_HexToStr( HB_HMAC_SHA256( cService, cSignKey ) )
   cSignKey := hb_HexToStr( HB_HMAC_SHA256( "aws4_request", cSignKey ) )

   // Firma final
   cSignature := Lower( HB_HMAC_SHA256( cStringToSign, cSignKey ) )

   // URL presignada completa
   cUrl := "https://" + cHost + cKey + "?" + cCanQuery + "&X-Amz-Signature=" + cSignature
   
   RETURN cUrl

// ============================================================================
// FUNCIONES DE SUBIDA A S3
// ============================================================================

/*
 * AWS_S3_UploadFile()
 * 
 * Sube contenido desde memoria a S3
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto destino
 *   cContent   - Contenido a subir (string/binario)
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez (default: 3600)
 * 
 * Retorna:
 *   { lSuccess, cMessage }
 *   lSuccess - .T. si subió correctamente
 *   cMessage - Mensaje descriptivo del resultado
 * 
 * Ejemplo:
 *   aResult := AWS_S3_UploadFile("mi-bucket", "datos/reporte.txt", ;
 *                                "Contenido del reporte...", ;
 *                                cAccessKey, cSecretKey, "us-east-1")
 *   IF aResult[1]
 *      ? "Subida exitosa:", aResult[2]
 *   ELSE
 *      ? "Error:", aResult[2]
 *   ENDIF
 */
FUNCTION AWS_S3_UploadFile(cBucket, cKey, cContent, cAccessKey, cSecretKey, cRegion, nExpires)
   LOCAL cUrl, hCurl, nResult, cResponse
   LOCAL nHttpCode := 0
   
   IF nExpires == NIL ; nExpires := 3600 ; ENDIF
   IF Empty(cRegion) ; cRegion := "us-east-1" ; ENDIF
   
   // Generar URL presignada para PUT
   cUrl := AWS_S3_GeneratePresignedUrl(cBucket, cKey, cAccessKey, ;
                                       cSecretKey, cRegion, nExpires, "PUT")
   
   curl_global_init()
   hCurl := curl_easy_init()
   
   IF Empty(hCurl)
      RETURN { .F., "No se pudo inicializar CURL" }
   ENDIF
   
   // Configurar request PUT
   curl_easy_setopt(hCurl, HB_CURLOPT_URL, cUrl)
   curl_easy_setopt(hCurl, HB_CURLOPT_UPLOAD, .T.)
   curl_easy_setopt(hCurl, HB_CURLOPT_CUSTOMREQUEST, "PUT")
   curl_easy_setopt(hCurl, HB_CURLOPT_UL_BUFF_SETUP, cContent)
   curl_easy_setopt(hCurl, HB_CURLOPT_INFILESIZE, Len(cContent))
   
   cResponse := ""
   curl_easy_setopt(hCurl, HB_CURLOPT_DL_BUFF_SETUP, @cResponse)
   
   curl_easy_setopt(hCurl, HB_CURLOPT_CONNECTTIMEOUT, 30)
   curl_easy_setopt(hCurl, HB_CURLOPT_TIMEOUT, 60)
   
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F.)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYHOST, .F.)
   
   nResult := curl_easy_perform(hCurl)
   
   IF nResult == HB_CURLE_OK
      nHttpCode := curl_easy_getinfo(hCurl, HB_CURLINFO_RESPONSE_CODE)
   ENDIF
   
   curl_easy_cleanup(hCurl)
   curl_global_cleanup()
   
   IF nResult == HB_CURLE_OK .AND. nHttpCode == 200
      RETURN { .T., "Archivo subido correctamente" }
   ENDIF
   
   RETURN { .F., "Error: " + curl_easy_strerror(nResult) + " (HTTP " + hb_NToS(nHttpCode) + ")" }

/*
 * AWS_S3_UploadFromFile()
 * 
 * Sube un archivo local a S3
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto destino en S3
 *   cLocalFile - Ruta del archivo local a subir
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez (default: 3600)
 * 
 * Retorna:
 *   { lSuccess, cMessage }
 * 
 * Ejemplo:
 *   aResult := AWS_S3_UploadFromFile("mi-bucket", "reportes/anual.pdf", ;
 *                                    "C:\datos\reporte.pdf", ;
 *                                    cAccessKey, cSecretKey)
 */
FUNCTION AWS_S3_UploadFromFile(cBucket, cKey, cLocalFile, cAccessKey, cSecretKey, cRegion, nExpires)
   LOCAL cContent
   
   IF !File(cLocalFile)
      RETURN { .F., "Archivo local no existe: " + cLocalFile }
   ENDIF

   cContent := MemoRead(cLocalFile)
   
   IF Empty(cContent)
      RETURN { .F., "No se pudo leer el archivo: " + cLocalFile }
   ENDIF
   
RETURN AWS_S3_UploadFile(cBucket, cKey, cContent, cAccessKey, cSecretKey, cRegion, nExpires)

// ============================================================================
// FUNCIONES DE DESCARGA DESDE S3
// ============================================================================

/*
 * AWS_S3_DownloadFile()
 * 
 * Descarga un objeto de S3 a memoria
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto a descargar
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez (default: 3600)
 * 
 * Retorna:
 *   { lSuccess, cContent, cMessage }
 *   lSuccess - .T. si descargó correctamente
 *   cContent - Contenido del archivo (NIL si error)
 *   cMessage - Mensaje descriptivo
 * 
 * Ejemplo:
 *   aResult := AWS_S3_DownloadFile("mi-bucket", "datos/reporte.txt", ;
 *                                  cAccessKey, cSecretKey)
 *   IF aResult[1]
 *      ? "Contenido:", aResult[2]
 *   ELSE
 *      ? "Error:", aResult[3]
 *   ENDIF
 */
FUNCTION AWS_S3_DownloadFile(cBucket, cKey, cAccessKey, cSecretKey, cRegion, nExpires)
   LOCAL cUrl, hCurl, nResult
   LOCAL nHttpCode := 0
   LOCAL cResponse := ""
   
   IF nExpires == NIL ; nExpires := 3600 ; ENDIF
   IF Empty(cRegion) ; cRegion := "us-east-1" ; ENDIF
   
   cUrl := AWS_S3_GeneratePresignedUrl(cBucket, cKey, cAccessKey, ;
                                       cSecretKey, cRegion, nExpires, "GET")
   
   curl_global_init()
   hCurl := curl_easy_init()
   
   IF Empty(hCurl)
      RETURN { .F., NIL, "No se pudo inicializar CURL" }
   ENDIF
   
   curl_easy_setopt(hCurl, HB_CURLOPT_URL, cUrl)
   curl_easy_setopt(hCurl, HB_CURLOPT_HTTPGET, .T.)
   
   // Forma estándar de Harbour para descargar a buffer (silencioso)
   curl_easy_setopt(hCurl, HB_CURLOPT_DOWNLOAD)
   curl_easy_setopt(hCurl, HB_CURLOPT_DL_BUFF_SETUP)
   
   curl_easy_setopt(hCurl, HB_CURLOPT_CONNECTTIMEOUT, 30)
   curl_easy_setopt(hCurl, HB_CURLOPT_TIMEOUT, 120)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F.)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYHOST, .F.)
   
   nResult := curl_easy_perform(hCurl)
   
   IF nResult == HB_CURLE_OK
      nHttpCode := curl_easy_getinfo(hCurl, HB_CURLINFO_RESPONSE_CODE)
      IF nHttpCode == 200
         cResponse := curl_easy_dl_buff_get(hCurl)
      ENDIF
   ENDIF
   
   curl_easy_cleanup(hCurl)
   curl_global_cleanup()
   
   IF nResult == HB_CURLE_OK .AND. nHttpCode == 200
      RETURN { .T., cResponse, "Archivo descargado correctamente" }
   ENDIF
   
RETURN { .F., NIL, "Error: " + curl_easy_strerror(nResult) + " (HTTP " + hb_NToS(nHttpCode) + ")" }

/*
 * AWS_S3_DownloadToFile()
 * 
 * Descarga un objeto de S3 directamente a disco
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto a descargar
 *   cLocalFile - Ruta donde guardar el archivo localmente
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez (default: 3600)
 * 
 * Retorna:
 *   { lSuccess, cMessage }
 * 
 * Ejemplo:
 *   aResult := AWS_S3_DownloadToFile("mi-bucket", "reportes/anual.pdf", ;
 *                                    "C:\descargas\reporte.pdf", ;
 *                                    cAccessKey, cSecretKey)
 */
FUNCTION AWS_S3_DownloadToFile(cBucket, cKey, cLocalFile, cAccessKey, cSecretKey, cRegion, nExpires)
   LOCAL cUrl, hCurl, nResult
   LOCAL nHttpCode := 0
   
   IF nExpires == NIL ; nExpires := 3600 ; ENDIF
   IF Empty(cRegion) ; cRegion := "us-east-1" ; ENDIF
   
   cUrl := AWS_S3_GeneratePresignedUrl(cBucket, cKey, cAccessKey, ;
                                       cSecretKey, cRegion, nExpires, "GET")
   
   curl_global_init()
   hCurl := curl_easy_init()
   
   IF Empty(hCurl)
      RETURN { .F., "No se pudo inicializar CURL" }
   ENDIF
   
   curl_easy_setopt(hCurl, HB_CURLOPT_URL, cUrl)
   curl_easy_setopt(hCurl, HB_CURLOPT_HTTPGET, .T.)
   
   // Forma estándar de Harbour para descargar a archivo (silencioso)
   curl_easy_setopt(hCurl, HB_CURLOPT_DOWNLOAD)
   curl_easy_setopt(hCurl, HB_CURLOPT_DL_FILE_SETUP, cLocalFile)
   
   curl_easy_setopt(hCurl, HB_CURLOPT_CONNECTTIMEOUT, 30)
   curl_easy_setopt(hCurl, HB_CURLOPT_TIMEOUT, 120)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F.)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYHOST, .F.)
   
   nResult := curl_easy_perform(hCurl)
   
   IF nResult == HB_CURLE_OK
      nHttpCode := curl_easy_getinfo(hCurl, HB_CURLINFO_RESPONSE_CODE)
   ENDIF
   
   curl_easy_setopt(hCurl, HB_CURLOPT_DL_FILE_CLOSE)
   curl_easy_cleanup(hCurl)
   curl_global_cleanup()
   
   IF nResult == HB_CURLE_OK .AND. nHttpCode == 200
      RETURN { .T., "Archivo guardado en: " + cLocalFile }
   ENDIF
   
   // Si falló, eliminar archivo parcial
   IF File(cLocalFile)
      FErase(cLocalFile)
   ENDIF
   
RETURN { .F., "Error: " + curl_easy_strerror(nResult) + " (HTTP " + hb_NToS(nHttpCode) + ")" }

// ============================================================================
// FUNCIÓN DE ELIMINACIÓN
// ============================================================================

/*
 * AWS_S3_DeleteObject()
 * 
 * Elimina un objeto de S3
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto a eliminar
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez (default: 3600)
 * 
 * Retorna:
 *   { lSuccess, cMessage }
 * 
 * Ejemplo:
 *   aResult := AWS_S3_DeleteObject("mi-bucket", "temp/archivo.txt", ;
 *                                  cAccessKey, cSecretKey)
 *   IF aResult[1]
 *      ? "Eliminado correctamente"
 *   ENDIF
 */
FUNCTION AWS_S3_DeleteObject(cBucket, cKey, cAccessKey, cSecretKey, cRegion, nExpires)
   LOCAL cUrl, hCurl, nResult, cResponse
   LOCAL nHttpCode := 0
   
   IF nExpires == NIL ; nExpires := 3600 ; ENDIF
   IF Empty(cRegion) ; cRegion := "us-east-1" ; ENDIF
   
   cUrl := AWS_S3_GeneratePresignedUrl(cBucket, cKey, cAccessKey, ;
                                       cSecretKey, cRegion, nExpires, "DELETE")
   
   curl_global_init()
   hCurl := curl_easy_init()
   
   IF Empty(hCurl)
      RETURN { .F., "No se pudo inicializar CURL" }
   ENDIF
   
   curl_easy_setopt(hCurl, HB_CURLOPT_URL, cUrl)
   curl_easy_setopt(hCurl, HB_CURLOPT_CUSTOMREQUEST, "DELETE")
   
   cResponse := ""
   curl_easy_setopt(hCurl, HB_CURLOPT_DL_BUFF_SETUP, @cResponse)
   
   curl_easy_setopt(hCurl, HB_CURLOPT_CONNECTTIMEOUT, 30)
   curl_easy_setopt(hCurl, HB_CURLOPT_TIMEOUT, 60)
   
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F.)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYHOST, .F.)
   
   nResult := curl_easy_perform(hCurl)
   
   IF nResult == HB_CURLE_OK
      nHttpCode := curl_easy_getinfo(hCurl, HB_CURLINFO_RESPONSE_CODE)
   ENDIF
   
   curl_easy_cleanup(hCurl)
   curl_global_cleanup()
   
   IF nResult == HB_CURLE_OK .AND. (nHttpCode == 204 .OR. nHttpCode == 200)
      RETURN { .T., "Objeto eliminado correctamente" }
   ENDIF
   
RETURN { .F., "Error: " + curl_easy_strerror(nResult) + " (HTTP " + hb_NToS(nHttpCode) + ")" }

// ============================================================================
// FUNCIÓN DE VERIFICACIÓN DE EXISTENCIA
// ============================================================================

/*
 * AWS_S3_ObjectExists()
 * 
 * Verifica si un objeto existe en S3 (usa método HEAD - más eficiente)
 * 
 * Parámetros:
 *   cBucket    - Nombre del bucket S3
 *   cKey       - Ruta/nombre del objeto a verificar
 *   cAccessKey - AWS Access Key ID
 *   cSecretKey - AWS Secret Access Key
 *   cRegion    - Región AWS (default: "us-east-1")
 *   nExpires   - Segundos de validez (default: 3600)
 * 
 * Retorna:
 *   { lSuccess, lExists, cMessage }
 *   lSuccess - .T. si la consulta fue exitosa
 *   lExists  - .T. si el objeto existe, .F. si no existe, NIL si error
 *   cMessage - Mensaje descriptivo
 * 
 * Ejemplo:
 *   aResult := AWS_S3_ObjectExists("mi-bucket", "datos/archivo.txt", ;
 *                                  cAccessKey, cSecretKey)
 *   IF aResult[1]
 *      IF aResult[2]
 *         ? "El archivo existe"
 *      ELSE
 *         ? "El archivo NO existe"
 *      ENDIF
 *   ELSE
 *      ? "Error al verificar:", aResult[3]
 *   ENDIF
 */
FUNCTION AWS_S3_ObjectExists(cBucket, cKey, cAccessKey, cSecretKey, cRegion, nExpires)
   LOCAL cUrl, hCurl, nResult
   LOCAL nHttpCode := 0
   LOCAL bQuiet

   IF nExpires == NIL ; nExpires := 3600 ; ENDIF
   IF Empty(cRegion) ; cRegion := "us-east-1" ; ENDIF

   // Generar URL presignada con método HEAD
   cUrl := AWS_S3_GeneratePresignedUrl(cBucket, cKey, cAccessKey, ;
                                       cSecretKey, cRegion, nExpires, "HEAD")

   curl_global_init()
   hCurl := curl_easy_init()

   IF Empty(hCurl)
      RETURN { .F., NIL, "No se pudo inicializar CURL" }
   ENDIF

   curl_easy_setopt(hCurl, HB_CURLOPT_URL, cUrl)
   curl_easy_setopt(hCurl, HB_CURLOPT_NOBODY, .T.)
   curl_easy_setopt(hCurl, HB_CURLOPT_CUSTOMREQUEST, "HEAD")

   // Callback silencioso (no esperamos body en HEAD)
   bQuiet := {|cData| Len(cData) }
   curl_easy_setopt(hCurl, HB_CURLOPT_WRITEFUNCTION, bQuiet)

   curl_easy_setopt(hCurl, HB_CURLOPT_CONNECTTIMEOUT, 30)
   curl_easy_setopt(hCurl, HB_CURLOPT_TIMEOUT, 120)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F.)
   curl_easy_setopt(hCurl, HB_CURLOPT_SSL_VERIFYHOST, .F.)

   nResult := curl_easy_perform(hCurl)

   IF nResult == HB_CURLE_OK
      nHttpCode := curl_easy_getinfo(hCurl, HB_CURLINFO_RESPONSE_CODE)
   ENDIF

   curl_easy_cleanup(hCurl)
   curl_global_cleanup()

   // Interpretar códigos HTTP
   // 200 = existe
   // 404 = no existe
   IF nResult == HB_CURLE_OK .AND. nHttpCode == 200
      RETURN { .T., .T., "El objeto existe" }
   ENDIF

   IF nResult == HB_CURLE_OK .AND. nHttpCode == 404
      RETURN { .T., .F., "El objeto NO existe" }
   ENDIF

RETURN { .F., NIL, "Error: " + curl_easy_strerror(nResult) + " (HTTP " + hb_NToS(nHttpCode) + ")" }

// ============================================================================
// FUNCIONES AUXILIARES PARA AWS SIGNATURE V4
// ============================================================================

/*
 * AWS_SigV4_CanonicalURI()
 * Codifica la URI según especificación AWS (RFC 3986)
 */
FUNCTION AWS_SigV4_CanonicalURI( cPath )
   LOCAL cRes := "", i, ch
   FOR i := 1 TO Len(cPath)
      ch := SubStr(cPath, i, 1)
      IF ch $ "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~/" 
         cRes += ch
      ELSE
         cRes += "%" + Upper( hb_NumToHex( Asc(ch), 2 ) )
      ENDIF
   NEXT
   RETURN cRes

/*
 * AWS_SigV4_CanonicalQueryString()
 * Normaliza y ordena los parámetros de query string según AWS Signature V4
 */
FUNCTION AWS_SigV4_CanonicalQueryString( cQuery )
   LOCAL aParams := {}, cPart, nPos, cName, cValue, i, cRes := ""

   DO WHILE !Empty(cQuery)
      nPos := At("&", cQuery)
      IF nPos == 0
         cPart := cQuery
         cQuery := ""
      ELSE
         cPart := Left(cQuery, nPos-1)
         cQuery := SubStr(cQuery, nPos+1)
      ENDIF
      
      nPos := At("=", cPart)
      IF nPos > 0
         cName  := Left(cPart, nPos-1)
         cValue := SubStr(cPart, nPos+1)
      ELSE
         cName  := cPart
         cValue := ""
      ENDIF
      AAdd(aParams, {cName, cValue})
   ENDDO

   ASort(aParams,,, {|x,y| x[1] < y[1]} )

   FOR i := 1 TO Len(aParams)
      cRes += AWS_SigV4_URLEncode(aParams[i][1]) + "=" + AWS_SigV4_URLEncode(aParams[i][2])
      IF i < Len(aParams)
         cRes += "&"
      ENDIF
   NEXT
   
   RETURN cRes

/*
 * AWS_SigV4_URLEncode()
 * Codifica caracteres según RFC 3986 (AWS requirement)
 */
FUNCTION AWS_SigV4_URLEncode( c )
   LOCAL cRes := "", i, ch
   LOCAL safe := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
   
   FOR i := 1 TO Len(c)
      ch := SubStr(c, i, 1)
      IF At(ch, safe) > 0
         cRes += ch
      ELSE
         cRes += "%" + Upper( hb_NumToHex( Asc(ch), 2 ) )
      ENDIF
   NEXT
   
   RETURN cRes

/*
 * AWS_SigV4_GetCurrentTimestamp()
 * Genera timestamp en formato ISO8601 (UTC) requerido por AWS
 * Formato: YYYYMMDDTHHMMSSZ
 * Ejemplo: 20251126T145034Z
 */
FUNCTION AWS_SigV4_GetCurrentTimestamp()
   LOCAL t := hb_TSToUTC( hb_DateTime() )
   
   RETURN hb_NToS(Year(t)) + ;
          PadL(Month(t),2,"0") + ;
          PadL(Day(t),2,"0") + "T" + ;
          PadL(HB_Hour(t),2,"0") + ;
          PadL(HB_Minute(t),2,"0") + ;
          PadL(Int(HB_Sec(t)),2,"0") + "Z"