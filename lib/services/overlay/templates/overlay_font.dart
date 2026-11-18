String overlayFontScript(bool googleFontsAllowed) => '''
const overlayGoogleFontsAllowed = $googleFontsAllowed;
$_applyOverlayFontScript
''';

const _applyOverlayFontScript = r'''
let overlayFontLink = null;
let overlayFontReloading = false;

function applyOverlayFont(settings) {
  const family = settings.chatFontFamily;
  if (typeof family !== 'string' || !/^[A-Za-z0-9 -]{1,48}$/.test(family) ||
      family !== family.trim()) return;
  const stylesheet = settings.googleFontStylesheet;
  if (Boolean(stylesheet) !== overlayGoogleFontsAllowed) {
    if (!overlayFontReloading) {
      overlayFontReloading = true;
      location.reload();
    }
    return;
  }
  const style = document.documentElement.style;
  if (family === 'Segoe UI') {
    style.removeProperty('--overlay-font-family');
  } else {
    style.setProperty('--overlay-font-family', '"' + family + '", "Segoe UI", sans-serif');
  }
  if (stylesheet && overlayFontLink?.href !== stylesheet) {
    if (overlayFontLink) overlayFontLink.remove();
    overlayFontLink = document.createElement('link');
    overlayFontLink.rel = 'stylesheet';
    overlayFontLink.href = stylesheet;
    document.head.appendChild(overlayFontLink);
  }
}
''';
