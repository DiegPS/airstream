# AirStream Privacy

AirStream is designed to work without an AirStream account and without an
AirStream-operated analytics or telemetry service.

## Data processed

- Public live-chat data is requested directly from YouTube, Twitch, and Kick.
  Those services receive the network information normally required to answer
  the request and apply their own privacy policies.
- OBS credentials, channel configuration, filters, window preferences, and
  model state are stored on the device. OBS passwords use the operating
  system's secure credential storage and are not included in the normal
  settings document.
- Text-to-speech, captions, and supported translations run locally. AirStream
  does not upload their text or audio to an AirStream server.
- The OBS browser-source server listens only on the local IPv4 loopback
  interface. It is not exposed to the local network by AirStream.
- Chat images and downloaded speech models may be cached on the device to
  improve performance and enable local processing.

## Diagnostic logs

AirStream writes rotating diagnostic logs on the device. Known passwords,
tokens, credentials, and sensitive structured fields are centrally redacted
before a record is written. Logs are not transmitted automatically. A user may
choose to share a log manually when requesting support.

## Data deletion

Uninstalling AirStream and deleting its application-data directory removes its
settings, logs, caches, and downloaded models. Platform-owned web or network
records are controlled by YouTube, Twitch, Kick, OBS, and the operating system.

## Support

Privacy and support questions can be submitted through the repository's issue
tracker: https://github.com/DiegPS/airstream/issues
