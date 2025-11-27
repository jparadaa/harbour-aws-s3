/*
 * test_s3.prg - Programa de prueba para librería AWS S3
 * 
 * Demuestra el uso de todas las funciones disponibles:
 *   - Subida desde memoria
 *   - Descarga a memoria
 *   - Subida desde disco
 *   - Descarga a disco
 *   - Eliminación de objetos
 *   - Verificación de existencia
 * 
 * Uso:
 *   Definir variables de entorno antes de ejecutar:
 *   SET AWS_ACCESS_KEY_ID=tu_access_key
 *   SET AWS_SECRET_ACCESS_KEY=tu_secret_key
 */

REQUEST HB_GT_WIN
REQUEST HB_CODEPAGE_UTF8
REQUEST HB_LANG_ES

PROCEDURE Main()
   LOCAL aResult
   LOCAL cBucket := "harbour-test-bucket"
   LOCAL cAccessKey := GetEnv("AWS_ACCESS_KEY_ID")
   LOCAL cSecretKey := GetEnv("AWS_SECRET_ACCESS_KEY")
   LOCAL cRegion := "us-east-1"
   LOCAL cTestKey := "test/archivo-prueba.txt"
   LOCAL cTestKey2 := "test/desde-disco.txt"
   LOCAL cContent 
   LOCAL aLines 
   LOCAL cLine

   hb_cdpSelect("UTF8")
   hb_LangSelect('ES')
   
   CLS
   
   ? "=========================================="
   ? "  TEST COMPLETO AWS S3 CON HARBOUR"
   ? "=========================================="
   ? "  Bucket:", cBucket
   ? "  Region:", cRegion
   ? "=========================================="
   ?
   
   // ============ PASO 1: SUBIR ARCHIVO DESDE MEMORIA ============
   ? "PASO 1: Subiendo archivo desde memoria..."
   ? "   Archivo:", cTestKey
   ?
   aResult := AWS_S3_UploadFile(cBucket, cTestKey, ;
                                 "Hola desde Harbour! " + DToC(Date()) + " " + Time(), ;
                                 cAccessKey, cSecretKey, cRegion)
   
   ? "   Resultado:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   ? "   Mensaje:", aResult[2]
   ?
   WAIT "Presione una tecla para continuar..."
   ?
   
   // ============ PASO 2: DESCARGAR A MEMORIA ============
   ? "PASO 2: Descargando archivo a memoria..."
   ?
   aResult := AWS_S3_DownloadFile(cBucket, cTestKey, ;
                                   cAccessKey, cSecretKey, cRegion)
   ?
   ? "   Resultado:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   IF aResult[1]
      ? "   Contenido:", aResult[2]
   ELSE
      ? "   Error:", aResult[3]
   ENDIF
   ?
   WAIT "Presione una tecla para continuar..."
   ?
   
   // ============ PASO 3: SUBIR DESDE DISCO ============
   ? "PASO 3: Subiendo archivo desde disco..."
   ? "   Creando archivo local..."
   MemoWrit("local_test.txt", "Contenido del archivo local" + hb_eol() + ;
            "Fecha: " + DToC(Date()) + hb_eol() + ;
            "Hora: " + Time())
   
   ? "   Subiendo a S3:", cTestKey2
   ?
   aResult := AWS_S3_UploadFromFile(cBucket, cTestKey2, ;
                                     "local_test.txt", ;
                                     cAccessKey, cSecretKey, cRegion)
   
   ? "   Resultado:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   ? "   Mensaje:", aResult[2]
   ?
   WAIT "Presione una tecla para continuar..."
   ?
   
   // ============ PASO 4: DESCARGAR A DISCO ============
   ? "PASO 4: Descargando archivo a disco..."
   ?
   aResult := AWS_S3_DownloadToFile(cBucket, cTestKey2, ;
                                     "descargado_test.txt", ;
                                     cAccessKey, cSecretKey, cRegion)
   ?
   ? "   Resultado:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   ? "   Mensaje:", aResult[2]
   ?
   IF aResult[1]
      ? "   Verificando contenido descargado..."
      ? "   ---"
      cContent := MemoRead("descargado_test.txt")
      aLines := hb_ATokens(cContent, hb_eol())      
      FOR EACH cLine IN aLines
         ? "   " + cLine
      NEXT
      ? "   ---"
   ENDIF
   ?
   WAIT "Presione una tecla para continuar..."
   ?
   
   // ============ PASO 5: ELIMINAR PRIMER ARCHIVO ============
   ? "PASO 5: Eliminando primer archivo de S3..."
   ? "   Archivo:", cTestKey
   ?
   aResult := AWS_S3_DeleteObject(cBucket, cTestKey, ;
                                   cAccessKey, cSecretKey, cRegion)
   
   ? "   Resultado:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   ? "   Mensaje:", aResult[2]
   ?
   WAIT "Presione una tecla para continuar..."
   ?
   
   // ============ PASO 6: VERIFICAR ELIMINACIÓN ============   
   ? "PASO 6: Verificando que el archivo fue eliminado..."
   ? "   Intentando verificar:", cTestKey
   ?
   aResult := AWS_S3_ObjectExists(cBucket, cTestKey, cAccessKey, cSecretKey, cRegion)

   ? "   Resultado consulta:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   IF aResult[1]
      IF aResult[2]
         ? "   Estado: ✗ ARCHIVO AÚN EXISTE"
      ELSE
         ? "   Estado: ✓ ARCHIVO ELIMINADO"
      ENDIF
   ELSE
      ? "   Error:", aResult[3]
   ENDIF
   ?
   WAIT "Presione una tecla para continuar..."
   ?
   
   // ============ PASO 7: ELIMINAR SEGUNDO ARCHIVO ============
   ? "PASO 7: Eliminando segundo archivo de S3..."
   ? "   Archivo:", cTestKey2
   ?
   aResult := AWS_S3_DeleteObject(cBucket, cTestKey2, ;
                                   cAccessKey, cSecretKey, cRegion)
   
   ? "   Resultado:", IIF(aResult[1], "✓ ÉXITO", "✗ ERROR")
   ? "   Mensaje:", aResult[2]
   ?
   
   // ============ LIMPIEZA LOCAL ============
   ? "=========================================="
   ? "LIMPIEZA: Eliminando archivos locales..."
   ?
   IF File("local_test.txt")
      FErase("local_test.txt")
      ? "   ✓ local_test.txt eliminado"
   ENDIF
   IF File("descargado_test.txt")
      FErase("descargado_test.txt")
      ? "   ✓ descargado_test.txt eliminado"
   ENDIF
   ?
   
   ? "=========================================="
   ? "  TEST COMPLETO FINALIZADO"
   ? "=========================================="
   ?
   WAIT "Presione cualquier tecla para salir..."
RETURN