/* Accept only the minimal viewer capability over the registered Cast namespace.
 * No HTML, arbitrary URLs, account sessions or room mutation messages. */
(() => {
 'use strict';const receiver=cast.framework.CastReceiverContext.getInstance();
 receiver.addCustomMessageListener('urn:x-cast:de.kartabend.scores',event=>{
  const m=event.data;if(!m||m.type!=='scores'||typeof m.session!=='string'||typeof m.code!=='string')return;
  window.HHTVReceiver.start(m.session,m.code);
 });receiver.start({disableIdleTimeout:true});
})();
