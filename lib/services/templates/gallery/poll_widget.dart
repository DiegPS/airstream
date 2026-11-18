import 'package:airstream/services/overlay/templates/poll_results.dart';

import 'gallery_base.dart';

Map<String, String> pollWidgetFiles() => galleryWidgetFiles(
      640,
      480,
      _body,
      '$pollResultsCss\n$_css',
      '$pollLabelsScript\n$pollResultsScript\n$_script',
    );

const _body = '''
<section class="widget-panel poll-panel">
  <header class="widget-header">
    <span class="gallery-logo" hidden></span>
    <h1 id="title"></h1>
  </header>
  <h2 id="question" dir="auto"></h2>
  <p id="instructions" hidden></p>
  <div id="results"></div>
  <footer id="status" aria-live="polite"></footer>
</section>
''';

const _css = r'''
.poll-panel {
  --poll-muted: var(--muted);
  --poll-track: var(--row);
  position: absolute; inset: 5px; padding: 16px 22px;
  display: grid; grid-template-rows: auto auto auto minmax(0, 1fr) auto; gap: 8px;
  border-top: 4px solid var(--accent);
}
.widget-header h1 { font-size: 17px; }
#question, #instructions { margin: 0; overflow-wrap: anywhere; }
#question {
  font-size: 28px; line-height: 1.12;
  display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2;
  overflow: hidden;
}
#instructions {
  color: var(--muted); font-size: 15px;
  display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2;
  overflow: hidden;
}
#results { grid-row: 4; display: grid; align-content: start; gap: 7px; overflow: auto; }
.option { padding: 4px 7px 5px; }
.option.winner { border-radius: 6px; background: var(--row); }
.row { display: flex; justify-content: space-between; gap: 10px; font-weight: 600; }
.command { color: var(--accent); margin-inline-end: 8px; }
.count { white-space: nowrap; color: var(--muted); font-variant-numeric: tabular-nums; }
.bar { height: 6px; margin-top: 4px; border-radius: 4px; background: var(--row); overflow: hidden; }
.fill { height: 100%; border-radius: 4px; background: var(--accent); }
.option.winner .bar { background: var(--line); }
.answers { margin-block: 0; }
.answer { line-height: 1.2; }
.answer.winner, .average.winner { border-radius: 5px; background: var(--row); }
.average.winner { padding-inline: 7px; }
#status { grid-row: 5; color: var(--muted); font-size: 14px; font-variant-numeric: tabular-nums; }
''';

const _script = r'''
const status = byId('status');
const instructions = byId('instructions');
let poll = null;
let pollTicker;

function drawPoll() {
  clearInterval(pollTicker);
  const labels = pollLabels[language];
  widgetTitle(labels.title);
  stage.hidden = !poll;
  if (!poll) {
    byId('question').textContent = '';
    instructions.hidden = true;
    instructions.textContent = '';
    byId('results').replaceChildren();
    status.textContent = '';
    return;
  }
  byId('question').textContent = poll.question;
  instructions.hidden = poll.closed;
  instructions.textContent = poll.closed ? '' : pollInstructions(poll, labels);
  byId('results').replaceChildren(...pollResultNodes(poll, language));
  const updateStatus = () => {
    const total = poll.total || 0;
    const votes = number(total) + (language === 'es'
      ? (total === 1 ? ' voto' : ' votos')
      : (total === 1 ? ' vote' : ' votes'));
    const remaining = !poll.closed && poll.endsAt
      ? Airstream.formatDuration(poll.endsAt - Date.now()) : '';
    const final = poll.closed ? (language === 'es' ? 'Resultados finales' : 'Final results') : '';
    status.textContent = [votes, remaining, final].filter(Boolean).join(' · ');
  };
  updateStatus();
  if (!poll.closed && poll.endsAt) pollTicker = setInterval(updateStatus, 1000);
}

configureWidget(drawPoll);
Airstream.on('poll', value => {
  poll = value;
  drawPoll();
});
// Like the built-in /poll: the server going away clears the card (and its
// ticker); the next snapshot draws it again on reconnect.
Airstream.on('disconnected', () => {
  poll = null;
  drawPoll();
});
''';
