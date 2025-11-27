# Harbour AWS S3: Implementación

Implementación en **Harbour** para interactuar con **Amazon S3** usando **AWS Signature Version 4 (SigV4)**.  

## 🌟 Características

- ✅ Subida de archivos (desde memoria o disco)  
- ✅ Descarga de archivos (a memoria o disco)  
- ✅ Eliminación de objetos  
- ✅ Verificación de existencia de objetos (HEAD optimizado)  
- ✅ Generación de URLs presignadas seguras con AWS SigV4  
- ✅ 100% nativo Harbour  

## 📋 Requisitos

- Cuenta AWS activa con credenciales (Access Key + Secret Key)  
- Bucket S3 creado en tu cuenta AWS  

## 📚 Funciones Disponibles

### `AWS_S3_UploadFile()`
Sube contenido desde memoria a S3.

### `AWS_S3_UploadFromFile()`
Sube un archivo local a S3.

### `AWS_S3_DownloadFile()`
Descarga un objeto de S3 a memoria.

### `AWS_S3_DownloadToFile()`
Descarga un objeto de S3 directamente a disco.

### `AWS_S3_DeleteObject()`
Elimina un objeto de S3.

### `AWS_S3_ObjectExists()`
Verifica si un objeto existe usando método HEAD (más eficiente).

### `AWS_S3_GeneratePresignedUrl()`
Genera una URL presignada para acceso temporal a objetos.

## ⚙️ Configurar credenciales

```bat
SET AWS_ACCESS_KEY_ID=tu_access_key_aqui
SET AWS_SECRET_ACCESS_KEY=tu_secret_key_aqui
```

🏃‍♂️ Programa de prueba

El programa de prueba realiza los siguientes pasos:
Subida desde memoria
Descarga a memoria
Subida desde disco
Descarga a disco
Eliminación de objetos
Verificación de existencia

🔐 Seguridad

Las credenciales nunca se incluyen en las URLs finales

Se utiliza AWS Signature V4 (estándar actual de AWS)
Las URLs presignadas expiran automáticamente (default: 1 hora)
Todas las conexiones usan HTTPS

📝 Nota sobre la autoría

Este proyecto fue implementado con herramientas de inteligencia artificial.
La supervisión, pruebas y validación fueron realizadas por Javier Parada, asegurándose de que toda la implementación funcionara correctamente en un entorno real de prueba con un bucket de AWS.

📄 Licencia

MIT License

Copyright (c) 2025 "Proyecto público"

EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA, INCLUYENDO PERO NO LIMITADO A LAS GARANTÍAS DE COMERCIABILIDAD, IDONEIDAD PARA UN PROPÓSITO PARTICULAR Y NO INFRACCIÓN. EN NINGÚN CASO LOS RESPONSABLES DE LA PUBLICACIÓN O LOS TITULARES DEL COPYRIGHT SERÁN RESPONSABLES DE NINGUNA RECLAMACIÓN, DAÑOS U OTRAS RESPONSABILIDADES, YA SEA EN UNA ACCIÓN DE CONTRATO, AGRAVIO O DE OTRO MODO, QUE SURJA DE O EN CONEXIÓN CON EL SOFTWARE O EL USO U OTROS TRATOS EN EL SOFTWARE.
