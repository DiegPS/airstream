const featuredSourceActivityScript = r'''
let obsSourceActive;
let registeredSourceSocket;
let lastReportedSourceActivity;
const obsStudio = window.obsstudio;

function sourceIsActive() {
  return obsSourceActive ?? (!obsStudio || document.visibilityState !== 'hidden');
}

function reportSourceActivity() {
  const active = sourceIsActive();
  if (socket !== registeredSourceSocket || socket?.readyState !== WebSocket.OPEN ||
      active === lastReportedSourceActivity) return;
  socket.send(JSON.stringify({type: 'sourceActivity', active}));
  lastReportedSourceActivity = active;
}

function setObsSourceActive(active) {
  if (typeof active !== 'boolean') return;
  obsSourceActive = active;
  reportSourceActivity();
}

function registerSource(connection, view) {
  registeredSourceSocket = connection;
  lastReportedSourceActivity = sourceIsActive();
  connection.send(JSON.stringify({type: 'register', view, active: lastReportedSourceActivity}));
}

window.addEventListener('obsSourceActiveChanged', event => {
  setObsSourceActive(event.detail?.active);
});
if (obsStudio) {
  obsStudio.onActiveChange = setObsSourceActive;
  document.addEventListener?.('visibilitychange', reportSourceActivity);
}
''';
