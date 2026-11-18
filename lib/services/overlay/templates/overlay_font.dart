const overlayFontScript = r'''
let overlayFontLink = null;

function applyOverlayFont(settings) {
  const family = settings.chatFontFamily;
  if (typeof family !== 'string' || !/^[A-Za-z0-9 -]{1,48}$/.test(family) ||
      family !== family.trim()) return;
  const stylesheet = settings.googleFontStylesheet;
  const style = document.documentElement.style;
  if (family === 'Segoe UI') {
    style.removeProperty('--overlay-font-family');
  } else {
    style.setProperty('--overlay-font-family', '"' + family + '", "Segoe UI", sans-serif');
  }
  if (overlayFontLink && overlayFontLink.href !== stylesheet) {
    overlayFontLink.remove();
    overlayFontLink = null;
  }
  if (stylesheet && !overlayFontLink) {
    overlayFontLink = document.createElement('link');
    overlayFontLink.rel = 'stylesheet';
    overlayFontLink.href = stylesheet;
    document.head.appendChild(overlayFontLink);
  }
}
''';
