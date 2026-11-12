# HidroNexo (app móvil, solo Android)

## Notificaciones push (Firebase Cloud Messaging)

La app registra su token FCM en el backend (`POST /devices`) y muestra las
alertas que el backend envía. Sin configuración de Firebase la app funciona
igual, solo sin push (se registra un mensaje en el log).

Paso manual, una sola vez:

1. Crea un proyecto en <https://console.firebase.google.com>.
2. Agrega una app Android con el paquete `mx.veracruz.agua_lluvia`.
3. Descarga `google-services.json` y colócalo en `movil/android/app/google-services.json`.
   Está en `.gitignore`: **no lo subas al repositorio**.
4. Para que el backend envíe, genera una clave de cuenta de servicio
   (Configuración del proyecto > Cuentas de servicio) y configúrala en el backend
   (ver su documentación).
5. `flutter run` (en Android 13+ la app pedirá el permiso de notificaciones).

El plugin `com.google.gms.google-services` solo se aplica si el archivo existe.
Con `--dart-define=USE_MOCK=true` el push está desactivado.
