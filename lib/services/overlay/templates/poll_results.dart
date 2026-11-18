import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

final pollLabelsScript = 'const pollLabels = ${jsonEncode({
      for (final locale in const [Locale('en'), Locale('es')])
        locale.languageCode: _pollLabels(lookupAppLocalizations(locale)),
    })};';

Map<String, String> _pollLabels(AppLocalizations l) => {
      'title': l.pollTitle,
      'hidden': l.pollResultsHidden,
      'average': l.pollAverage,
      'distinct': l.pollDistinctAnswers,
      'howToVote': l.pollHowToVote,
      'answerExample': l.pollAnswerExample,
      'noAnswers': l.pollNoAnswers,
    };

// Shared by the built-in page and the gallery widget. The caller supplies
// textElement, which creates a DOM element and sets its textContent.
const pollResultsScript = r'''
const pollMode = poll => poll.mode || 'numbered';
const pollCommand = (mode, index) => mode === 'numbered' || mode === 'yesNo' ? '!' + (index + 1) : '';

function pollInstructions(poll, labels) {
  const mode = pollMode(poll);
  const help = mode === 'rating' ? '1–10' :
    mode === 'freeAnswer' ? (poll.command || '!r') + ' ' + labels.answerExample :
    poll.options.map((option, index) => pollCommand(mode, index) || option.label).join(' / ');
  return labels.howToVote + ': ' + help;
}

function pollResultNodes(poll, language) {
  const labels = pollLabels[language] || pollLabels.en;
  const mode = pollMode(poll);
  const options = poll.options || [];
  if (poll.hidden && !poll.closed) {
    return [
      textElement('div', 'results-hidden', labels.hidden),
      ...options.map((option, index) => pollOption(option, mode, index, false, false)),
    ];
  }

  if (mode === 'rating') {
    const average = poll.average == null ? '—' :
      new Intl.NumberFormat(language, {minimumFractionDigits: 1, maximumFractionDigits: 1}).format(poll.average);
    const distribution = document.createElement('div');
    distribution.className = 'distribution';
    const counts = poll.distribution || [];
    const peak = Math.max(1, ...counts);
    counts.forEach((votes, index) => {
      const bucket = document.createElement('div');
      bucket.className = 'bucket';
      const bar = document.createElement('div');
      bar.className = 'bucket-bar';
      const fill = document.createElement('div');
      fill.className = 'fill';
      fill.style.height = Math.min(100, Math.max(0, votes / peak * 100)) + '%';
      bar.appendChild(fill);
      bucket.append(textElement('span', 'bucket-count', votes), bar,
        textElement('span', 'bucket-label', index + 1));
      distribution.appendChild(bucket);
    });
    return [textElement('div', poll.closed && poll.total ? 'average winner' : 'average',
      labels.average + ': ' + average), distribution];
  }

  if (mode === 'freeAnswer') {
    const list = document.createElement('ol');
    list.className = 'answers';
    (poll.answers || []).forEach((answer, index) => {
      const row = document.createElement('li');
      row.className = poll.closed && index === 0 ? 'answer winner' : 'answer';
      row.append(textElement('bdi', 'label', answer.text),
        textElement('span', 'count', answer.votes));
      list.appendChild(row);
    });
    return list.children.length ? [
      list, textElement('div', 'distinct', labels.distinct + ': ' + poll.distinct),
    ] : [textElement('div', 'empty-answers', labels.noAnswers)];
  }

  const leader = Math.max(0, ...options.map(option => option.votes || 0));
  return options.map((option, index) => {
    const leading = leader > 0 && option.votes === leader;
    return pollOption(option, mode, index, true, leading, poll.closed && leading);
  });
}

function pollOption(option, mode, index, showResults, leading, winner) {
  const row = document.createElement('div');
  row.className = 'option' + (leading ? ' leader' : '') + (winner ? ' winner' : '');
  const head = document.createElement('div');
  head.className = 'row';
  const label = document.createElement('span');
  label.className = 'label';
  const command = pollCommand(mode, index);
  if (command) label.appendChild(textElement('span', 'command', command));
  label.appendChild(textElement('bdi', '', option.label));
  head.appendChild(label);
  row.appendChild(head);
  if (showResults) {
    head.appendChild(textElement('span', 'count', option.percent + '% · ' + option.votes));
    const bar = document.createElement('div');
    bar.className = 'bar';
    const fill = document.createElement('div');
    fill.className = 'fill';
    fill.style.width = Math.min(100, Math.max(0, option.percent)) + '%';
    bar.appendChild(fill);
    row.appendChild(bar);
  }
  return row;
}
''';

const pollResultsCss = r'''
.label { min-width: 0; overflow-wrap: anywhere; }
.results-hidden, .distinct, .empty-answers { color: var(--poll-muted); }
.average { font-size: 1.35em; font-weight: 700; }
.distribution { display: grid; grid-template-columns: repeat(10, minmax(0, 1fr)); gap: 5px; margin-block: 8px; }
.bucket { display: grid; grid-template-rows: auto 70px auto; gap: 4px; text-align: center; font-size: 13px; font-variant-numeric: tabular-nums; }
.bucket-bar { display: flex; align-items: end; overflow: hidden; border-radius: 4px; background: var(--poll-track); }
.bucket-bar .fill { width: 100%; }
.bucket-count { color: var(--poll-muted); }
.answers { margin: 10px 0 6px; padding-inline-start: 26px; }
.answer { padding-inline-start: 4px; margin-block: 2px; }
.answer .count { float: inline-end; margin-inline-start: 10px; }
.answer.winner, .average.winner { font-weight: 800; }
''';
