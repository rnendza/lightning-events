({
    /**
     * cometd [publish / subscribe]... Handshake - (callback) - subscribe) fire event so vf can listen.
     *
     * Note. I'd rather have an array of channels here but that just wont work with cometD. I tried....
     * Trust me. It needs hard refs to the listeners for its callbacks.
     *
     * It also doesn't appear SFDC lets you wildcard channel subs (not a shocker)
     *
     * So.... you need to create this component once for ever different pushtopic or platform event you are using.
     * Not too bad as it should be relatively light. compared to intensive viewstate.
     *
     * Much of this was taken with the help of Andrew Fwcett CIO of Financial Force.. but I had to
     * really tune it to get it past the pure demo mode. As with any component, much of the gutz
     * is in the helper.
     *
     * @param component  This component.
     * @param event      Any system event.
     * @param helper
     */
    doInit: function (component, event, helper) {
        try {
            var debugMode = component.get('v.debugMode');
            if (debugMode !== 'debug' && debugMode !== 'info' && debugMode !== 'warn') {
                debugMode = 'warn';
                component.set('v.debugMode', debugMode);
            }
            var action = component.get("c.sessionId");
            action.setCallback(this, function (response) {
                // Configure CometD for this component
                var sessionId = response.getReturnValue();
                var cometd = new window.org.cometd.CometD();
                component.set('v.cometd', cometd);
                //replay extension functionality... be careful passing -2 in here (ie all for last 24 hours)
                if (component.get('v.useReplayExt')) {
                    helper.registerReplayExtension(component, event, helper);
                }
                var url = window.location.protocol + '//' + window.location.hostname + '/cometd/41.0/';
                var logLevel = debugMode;
                if (component.get('v.debugMode') === 'debug') {
                    helper.log('--- streamer. configuring cometd with url=' + url, 'info');
                }
                cometd.websocketEnabled = false;
                cometd.configure({
                    url: url,
                    requestHeaders: {Authorization: 'OAuth ' + sessionId},
                    appendMessageTypeToURL: false,
                    logLevel: logLevel
                });
                component.set('v.cometd', cometd);
                helper.addConnectListener(component, event, helper);
                helper.addOnListenerException(component, event, helper);
                helper.addHandshakeListener(component, event, helper);
                helper.handshake(component, event, helper);
            });
            $A.enqueueAction(action);
        } catch (e) {
            alert('streamer'+e);
        }
    },
    /**
     * Once this component is 'destroyed' ie THIS (see handler in component)
     * handleDestroy will fire and unsubscribe well as disconnect from cometd so
     * the server isn't sending messages to outer space of perhaps even dup messages!
     *
     * @param component
     * @param event
     * @param helper
     */
    handleDestroy: function (component, event, helper) {
        helper.handleDestroy(component,event,helper);
    }
})