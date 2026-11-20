const featuredMessageItemStyles = '''
.emote { height: 1.15em; width: auto; vertical-align: -.21em; }
.emote-stack { display: inline-grid; vertical-align: -.21em; }
.emote-stack > img { grid-area: 1 / 1; }
''';

const featuredMessageItemsScript = r'''
function renderFeaturedItems(message, items) {
  // Hold spaces until we know whether an emote modifies the previous base.
  let stack = null, pendingSpace = '';
  const flush = () => {
    if (pendingSpace) message.append(document.createTextNode(pendingSpace));
    pendingSpace = '';
  };
  for (const item of items) {
    if (item.kind !== 'emoji') {
      const value = item.text || '';
      if (stack && value.trim() === '') {
        pendingSpace += value;
        continue;
      }
      flush();
      message.append(document.createTextNode(value));
      stack = null;
      continue;
    }
    const alt = item.alt || '';
    if (typeof item.url !== 'string' || !/^https?:\/\//i.test(item.url)) {
      flush();
      message.append(document.createTextNode(alt));
      stack = null;
      continue;
    }
    const image = document.createElement('img');
    image.className = 'emote';
    image.alt = alt;
    image.referrerPolicy = 'no-referrer';
    image.addEventListener('error', () => {
      if (alt) image.replaceWith(document.createTextNode(alt));
      else image.remove();
    }, { once: true });
    image.src = item.url;
    if (item.isZeroWidth && stack) {
      pendingSpace = '';
    } else {
      flush();
      stack = document.createElement('span');
      stack.className = 'emote-stack';
      message.append(stack);
    }
    stack.append(image);
  }
  flush();
}
''';
