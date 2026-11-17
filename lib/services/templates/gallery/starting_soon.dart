import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

List<Map<String, Object?>> startingSoonFields(AppLocalizations l) => [
      ...screenFields(l),
      screenTextField('title', l.galleryScreenTitle, 100),
      screenTextField('subtitle', l.gallerySubtitle, 160),
      screenTextField('startTime', l.galleryStartTime, 5),
      screenToggle('showChat', l.galleryShowChat, true),
    ];

Map<String, String> startingSoonFiles() => screenFiles(
      'starting',
      '''
<div class="screen-content screen-break">
  <section class="screen-hero">
    <h1 id="title" class="screen-title"></h1>
    <p id="subtitle" class="screen-subtitle" hidden></p>
    <p id="countdown" class="screen-countdown" hidden></p>
  </section>
  $screenChat
</div>
''',
      _script,
    );

const _script = r'''
const startingCopy = {
  en: {title: 'Starting soon', now: 'Starting now'},
  es: {title: 'Empezamos pronto', now: 'Empezamos ahora'}
};
function startingTime() {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(fields.startTime || '');
  if (!match) return galleryDemo && !fields.startTime ? Date.now() + 5 * 60000 : null;
  const now = Date.now();
  const target = new Date(now);
  target.setHours(Number(match[1]), Number(match[2]), 0, 0);
  if (now - target.getTime() > 30 * 60000) target.setDate(target.getDate() + 1);
  return target.getTime();
}
const countdown = setupCountdown(startingTime, () => startingCopy[language].now);
let previousTime;
configureScreen(first => {
  localTitle(fields.title || startingCopy[language].title);
  subtitleText(fields.subtitle || '');
  if (first || fields.startTime !== previousTime) countdown.restart();
  else countdown.update();
  previousTime = fields.startTime;
});
''';
