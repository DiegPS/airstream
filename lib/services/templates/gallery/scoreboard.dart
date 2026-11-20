import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

const scoreboardWidth = 960;
const scoreboardHeight = 520;

List<Map<String, Object?>> scoreboardFields(AppLocalizations l) => [
      screenTextField('counters', l.galleryScoreboardCounters, 300),
      screenTextField('labels', l.galleryScoreboardLabels, 300),
      {
        'key': 'layout',
        'label': l.galleryScoreboardLayout,
        'type': 'select',
        'options': ['row', 'column'],
        'default': 'row',
      },
    ];

Map<String, String> scoreboardFiles() => galleryWidgetFiles(
      scoreboardWidth,
      scoreboardHeight,
      _body,
      _css,
      'const copy = ${widgetCopy(_strings)};\n$_script',
    );

Map<String, String> _strings(AppLocalizations l) => {
      'title': l.galleryScoreboard,
      'home': l.galleryScoreboardHome,
      'away': l.galleryScoreboardAway,
    };

const _body = """
<span class="gallery-logo corner-logo" hidden></span>
<h1 id="title" class="score-title"></h1>
<div id="scores"></div>
""";

const _css = r"""
.score-title { position: absolute; width: 1px; height: 1px; clip-path: inset(50%); overflow: hidden; }
#scores { position: absolute; inset: 10px; display: flex; align-items: stretch;
  justify-content: center; align-content: center; flex-wrap: wrap; gap: 9px; }
#scores[data-layout=column] { flex-direction: column; align-items: center; flex-wrap: nowrap; }
.score { display: grid; min-width: 100px; max-width: 210px; padding: 10px;
  gap: 5px; text-align: center; border-block-end: 3px solid var(--accent); }
#scores[data-layout=column] .score { display: flex; width: min(100%, 580px);
  align-items: baseline; justify-content: space-between; column-gap: 24px; padding-block: 4px; }
.score-label, .score-value { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.score-label { font-size: 20px; color: var(--muted); }
.score-value { font-size: 33px; font-weight: 760; font-variant-numeric: tabular-nums; }
""";

const _script = r"""
const scores = byId('scores');
let ready = false;
let stale = false;
const split = source => String(source || '').split(/[,|\n]/).map(value => value.trim());
function render() {
  if (!ready) return;
  widgetTitle(copy[language].title);
  const counters = split(fields.counters);
  const labels = split(fields.labels);
  const demo = Airstream.demo && counters.every(key => !key);
  const keys = new Set((demo ? ['home', 'away'] : counters)
    .filter(key => /^[a-z0-9_]{1,30}$/.test(key)));
  const demoLabels = [copy[language].home, copy[language].away];
  const values = Airstream.state.counters || {};
  scores.dataset.layout = fields.layout === 'column' ? 'column' : 'row';
  scores.replaceChildren(...[...keys].slice(0, 8).map((key, index) => {
    const score = textElement('div', 'widget-panel score', '');
    const label = demo ? demoLabels[index] : labels[counters.indexOf(key)] || key;
    const value = Object.prototype.hasOwnProperty.call(values, key) ? values[key] : 0;
    score.appendChild(textElement('span', 'score-label', label));
    score.appendChild(textElement('strong', 'score-value', number(value)));
    return score;
  }));
  stage.hidden = !keys.size || stale;
}
// Without the server the score may be out of date: hide it until the next
// counter snapshot arrives.
Airstream.on('counters', () => { stale = false; render(); });
Airstream.on('disconnected', () => { stale = true; render(); });
configureWidget(() => { ready = true; render(); });
""";
