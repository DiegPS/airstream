# Airstream Privacy Policy

Last updated: November 21, 2026

Airstream is a Windows app for streamers that shows YouTube, Twitch and Kick
live chat and serves overlays to OBS. It works without an Airstream account
and Airstream has no server, analytics or telemetry of its own. The developer
does not receive any of your data.

## What Airstream connects to

- **Live chat platforms.** Public chat, channel and stream information is
  requested directly from YouTube, Twitch and Kick for the channels you add.
  Airstream joins chats without signing in to your account.
- **Emote services.** Emote images and lists are loaded from 7TV, BetterTTV
  and FrankerFaceZ for the channels you add.
- **Model downloads.** Text-to-speech and speech-recognition models are
  downloaded from GitHub and Hugging Face only when you choose to install one.
- **OBS.** Airstream connects to the OBS WebSocket address you configure.
- **Destinations you choose.** A rule with an HTTP request action (for example
  a Discord webhook) sends the data you put in that action to the URL you
  enter. An overlay template you allow to use the network can load content
  from, and send data to, other websites; Airstream shows a warning when you
  grant that permission. Nothing is sent this way unless you set it up.

Each of these services receives the network information needed to answer the
request (such as your IP address) and applies its own privacy policy.

## Data stored on your device

- Settings, channels, filters, rules, templates, media files, polls, goals,
  giveaway history and window preferences are stored in Airstream's
  application-data folder.
- The OBS password is kept in Windows' secure credential storage. It is not
  included in the settings file, exports or backups.
- Chat images and downloaded models are cached on the device.
- Chat exports (CSV) and backups are only created when you ask for them, in
  the location you pick.

## Microphone

The microphone is used only while live captions or voice commands are turned
on. Speech recognition, translation and text-to-speech run entirely on your
device; Airstream does not upload audio or text for them.

## OBS overlay server

The overlay server used by OBS browser sources listens only on your computer's
local loopback address (127.0.0.1). It is not reachable from your network or
the Internet.

## Diagnostic logs

Airstream writes rotating diagnostic logs on the device. Passwords, tokens and
other sensitive fields are removed before anything is written. Logs are never
sent automatically; you may choose to share one when asking for support.

## Children

Airstream is not directed at children and does not knowingly collect data from
anyone.

## Deleting your data

Uninstalling Airstream removes the app. Deleting its application-data folder
removes its settings, logs, caches and downloaded models. Data held by
YouTube, Twitch, Kick, emote services or OBS is governed by those services.

## Changes and contact

Changes to this policy are published in this file. Questions can be sent
through the issue tracker: https://github.com/DiegPS/airstream/issues

---

# Política de privacidad de Airstream

Última actualización: 21 de noviembre de 2026

Airstream es una app de Windows para streamers que muestra el chat en directo
de YouTube, Twitch y Kick y sirve overlays a OBS. Funciona sin cuenta de
Airstream y no tiene servidor, analíticas ni telemetría propios. El
desarrollador no recibe ninguno de tus datos.

## A qué se conecta Airstream

- **Plataformas de chat.** El chat público y la información del canal y del
  directo se piden directamente a YouTube, Twitch y Kick para los canales que
  añades. Airstream entra a los chats sin iniciar sesión en tu cuenta.
- **Servicios de emotes.** Las imágenes y listas de emotes se cargan de 7TV,
  BetterTTV y FrankerFaceZ para los canales que añades.
- **Descarga de modelos.** Los modelos de voz y de reconocimiento de voz se
  descargan de GitHub y Hugging Face solo cuando eliges instalar uno.
- **OBS.** Airstream se conecta a la dirección de OBS WebSocket que configures.
- **Destinos que eliges tú.** Una regla con la acción de petición HTTP (por
  ejemplo, un webhook de Discord) envía los datos que pongas en esa acción a
  la URL que escribas. Una plantilla de overlay a la que permitas usar la red
  puede cargar contenido de otros sitios web y enviarles datos; Airstream
  muestra un aviso al dar ese permiso. No se envía nada así si no lo
  configuras tú.

Cada uno de estos servicios recibe la información de red necesaria para
responder (como tu dirección IP) y aplica su propia política de privacidad.

## Datos guardados en tu equipo

- Ajustes, canales, filtros, reglas, plantillas, archivos multimedia,
  encuestas, metas, historial de sorteos y preferencias de ventana se guardan
  en la carpeta de datos de la aplicación.
- La contraseña de OBS se guarda en el almacén seguro de credenciales de
  Windows. No se incluye en el archivo de ajustes, en las exportaciones ni en
  las copias de seguridad.
- Las imágenes del chat y los modelos descargados se guardan en caché.
- Las exportaciones del chat (CSV) y las copias de seguridad solo se crean
  cuando las pides, en la ubicación que eliges.

## Micrófono

El micrófono solo se usa mientras los subtítulos en directo o los comandos de
voz están activados. El reconocimiento de voz, la traducción y la lectura en
voz alta funcionan por completo en tu equipo; Airstream no sube audio ni texto
para ello.

## Servidor de overlays para OBS

El servidor que usan las fuentes de navegador de OBS solo escucha en la
dirección local de tu equipo (127.0.0.1). No es accesible desde tu red ni
desde Internet.

## Registros de diagnóstico

Airstream escribe registros de diagnóstico rotativos en el equipo. Las
contraseñas, tokens y otros campos sensibles se eliminan antes de escribir
nada. Los registros nunca se envían solos; puedes compartir uno si pides
ayuda.

## Menores

Airstream no está dirigida a menores y no recopila datos de nadie a sabiendas.

## Borrar tus datos

Desinstalar Airstream elimina la app. Borrar su carpeta de datos elimina sus
ajustes, registros, cachés y modelos descargados. Los datos que guardan
YouTube, Twitch, Kick, los servicios de emotes u OBS dependen de esos
servicios.

## Cambios y contacto

Los cambios de esta política se publican en este archivo. Las preguntas se
pueden enviar por el gestor de incidencias:
https://github.com/DiegPS/airstream/issues
