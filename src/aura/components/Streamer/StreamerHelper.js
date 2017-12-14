({
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
        // Ensure this component unsubscribes and disconnects from the server
        // note: alot of times cometd.js is doing this for us but just to be sure.
        var cometd = component.get("v.cometd");
        var subscription = component.get("v.subscription");
        if(cometd && subscription) {
            cometd.unsubscribe(subscription, {}, function (unsubscribeReply) {
                if (unsubscribeReply.successful) {
                    cometd.disconnect(function (disconnectReply) {
                        if (disconnectReply.successful) {
                            helper.log('--- streamer: Success disconnect','info');
                        } else {
                            helper.log('--- streamer: Failed disconnect','error');
                        }
                    });
                } else {
                    if(unsubscribeReply && unsubscribeReply.error && unsubscribeReply.error.includes('403')) {
                        helper.log('--- streamer: unsubscribe not successful','warn',unsubscribeReply);
                    } else {
                        helper.log('--- streamer: Failed unsubscribe','error',unsubscribeReply);
                    }
                }
            });
        }
    },
    /**
     * Adding a generic cometd onListnerException.
     *
     * @param component
     * @param event
     * @param helper
     */
    addOnListenerException: function(component, event, helper) {
        var cometd = component.get("v.cometd");
        cometd.onListenerException = function(exception, subscriptionHandle, isListener, message) {
            helper.log('--- streamer onListenerException exception=','debug',exception);
            helper.log('--- streamer onListenerException message=','debug',message);
            // Uh-oh, something went wrong, disable this listener/subscriber
            // Object "this" points to the CometD object
            //if (isListener) {
            //    this.removeListener(subscriptionHandle);
            //} else {
            //    this.unsubscribe(subscriptionHandle);
            //}
        }
    },
    /**
     * A meta/handshake listener for cometd. generally cometd should rehandshake on it's own but in case we have issues
     * this may be the spot to address.
     *
     * @param component
     * @param event
     * @param helper
     */
    addHandshakeListener: function(component, event, helper) {
        //--- extra meta/connect listener for further bulletproofing.... this makes me sad that we have to do this!!
        var cometd = component.get("v.cometd");
        cometd.addListener('/meta/handshake',$A.getCallback(function(handshake) {
            if(!handshake.successful) {
                helper.log('--- streamer meta/handshake.. .. error..','debug',handshake);
            }
        }));
    },
    /**
     * A meta/connect listener for cometd. generally cometd should rehandshake on it's own but in case we have issues
     * this may be the spot to address.
     *
     * @param component
     * @param event
     * @param helper
     */
    addConnectListener: function(component, event, helper) {
        //--- extra meta/connect listener for further bulletproofing.... this makes me sad that we have to do this!!
        var cometd = component.get("v.cometd");
        cometd.addListener('/meta/connect',$A.getCallback(function(message) {
            if(!message.successful) {
                helper.log('--- streamer meta/connect..xxx isDisconnected?' + cometd.isDisconnected() + '... message.error..'+message.error + 'advice=' + JSON.stringify(message.advice) + '..  message='+JSON.stringify(message),'warn',message);
                var advice = message.advice;

                //if(reconnect && reconnect!==undefined && reconnect != null) {
                if(message.error.includes('403')) {
                    helper.log('--- streamer.. cometd will attempt to rehandshake on its own according to spec but always fails after the next handshake !! im forcing an entire reinit of the component doing a handledestroy here doesnot seem necessary as unsubscribe always fails.', 'warn');
                    helper.doReInit(component, event, helper);
                }
                    //------------------------helper.handshake(component,event.helper);
                //}
            }
        }));
    },
    /**
     * The big Kahuna.  this is where all the action takes place.
     * Handshake --> Subscrbe on the successful cb of the handshake / fire an event with the payload.
     *
     * @param component
     * @param event
     * @param helper
     */
    handshake: function( component,event, helper) {
        var cometd = component.get("v.cometd");
        try {
            //note once in a while cometd is swallowing unrecognized advice on handshake.
            //i see no way to handle that since this is asych and they are catching it internally
            //and there is nothing documented on that. that causes us to lose the refresh. as some internal
            //cometd debugging is showing sfdc is sending back a 403
            cometd.handshake($A.getCallback(function (status) {
                if (status.successful) {
                    var eventName = component.get("v.channel");
                    if(component.get("v.channel") == null || component.get("v.channel") == '' ||  component.get("v.channel") == undefined) {
                        helper.log('--- streamer no channel argument passed..','error');
                        return;
                    }
                    helper.log('--- streamer.. subscribing to channel=' + eventName,'info');
                    var subscription =
                        cometd.subscribe(eventName, $A.getCallback(function (message) {
                                helper.log('--- streamer message recieved for '+eventName,'info');
                                //--- prefer vf event fall back to lightning event.
                                //--- note vfEventName passes a string event name as an attribute.. i hate doing it this way
                                //--- but i don't see a better supported / documented option in lightning out.
                                try {
                                    //ie. c:NewEvent
                                    var vfEventName = component.get('v.vfEventName');
                                    if (vfEventName != null && vfEventName != '') {
                                        var vfMessageEvent = $A.get('e.' + vfEventName);
                                        if (vfMessageEvent != null) {
                                            message.data.channel = eventName;
                                            vfMessageEvent.setParam("payload", message.data);
                                            vfMessageEvent.fire();
                                        }
                                    } else {
                                        //lightning event passed in from parent component.
                                        var lightningMessageEvent = component.getEvent("onLightningMessage");
                                        if (lightningMessageEvent != null) {
                                            message.data.channel = eventName;
                                            lightningMessageEvent.setParam("payload", message.data);
                                            lightningMessageEvent.fire();
                                        }
                                    }
                                } catch (e) {
                                    helper.log('--- streamer caught error firing event.. ','error',e);
                                }
                            }
                        ));
                    component.set('v.subscription', subscription);
                } else {
                    // TODO: Throw an event / set error property here?
                    helper.log('--- streamer handshake problem status: ' + status + ' message:','error',message);
                }
            }));
        } catch(e) {
            helper.log('--- streamer caught error processing subscribe.. ','error',e);
        }
    },
    /**
     * Register the replay extension. note if a replay from of -2 is used more code will need to be developed to decide
     * how to handle all the events that come from the past 24 hours.
     *
     * @param component
     * @param event
     * @param helper
     */
    registerReplayExtension: function(component,event,helper) {
        var cometd = component.get('v.cometd');
        try {
            var CARPLS_REPLAY_FROM = -1; //give all all events from the last time something went wrong.
            var pFrom = component.get('v.replayFromValue');
            if(pFrom && pFrom != null) {
                CARPLS_REPLAY_FROM = pFrom;
            }
            var channel = component.get("v.channel");
            var replayExtension = new window.org.cometd.CarplsReplayExtension();
            //note. i had to modify the standard replyextension sfdc created as it doesn't work with lockerservice..
            replayExtension.setChannel(channel);
            replayExtension.setReplay(CARPLS_REPLAY_FROM);
            cometd.registerExtension('replayExtension', replayExtension);
            if(component.get('v.debugMode') === 'debug') {
                helper.log('--- streamer - registered replayextension', 'info');
            }

        } catch (e) {
            helper.log('--- streamer error: trying to reg replayExtention e=:','error',e);
        }
    },
    /**
     * Simple a wrapper around console.log. either call it with just a string msg / mode or
     * a string msg and the mode and an object.
     *
     * @param msg
     * @param mode [debug,info,warn,error]
     * @param jsonObj  optional
     */
    log: function(msg,mode,jsonObj) {

        if ( arguments.length ===2) {
            switch(mode) {
                case 'debug':
                    console.debug(msg);
                    break;
                case 'info':
                    console.info(msg);
                    break;
                case 'warn' :
                    console.warn(msg);
                    break;
                case 'error' :
                    console.error(msg);
                    break;
                default:
                    console.log(msg);
            }
        } else if ( arguments.length === 3 ) {
                if (typeof jsonObj === 'object') {
                    switch(mode) {
                        case 'debug':
                            console.debug(msg);
                            console.debug(jsonObj);
                            break;
                        case 'info':
                            console.info(msg);
                            console.info(jsonObj);
                            break;
                        case 'warn' :
                            console.warn(msg);
                            console.warn(jsonObj);
                            break;
                        case 'error' :
                            console.error(msg);
                            console.error(jsonObj);
                            break;
                        default:
                            console.log(msg);
                            console.log(jsonObj);
                    }
                }
        }
    },
    doReInit: function (component, event, helper) {
        var debugMode = component.get('v.debugMode');
        if(debugMode!=='debug' && debugMode!=='info' && debugMode !=='warn') {
            debugMode='warn';
            component.set('v.debugMode',debugMode);
        }
        var action = component.get("c.sessionId");
        action.setCallback(this, function (response) {
            // Configure CometD for this component
            var sessionId = response.getReturnValue();
            var cometd = new window.org.cometd.CometD();
            component.set('v.cometd', cometd);
            //replay extension functionality... be careful passing -2 in here (ie all for last 24 hours)
            if (component.get('v.useReplayExt')) {
                helper.registerReplayExtension(component,event,helper);
            }
            var url =  window.location.protocol + '//' + window.location.hostname + '/cometd/41.0/';
            var logLevel = debugMode;
            if(component.get('v.debugMode') === 'debug') {
                helper.log('--- streamer. configuring cometd with url=' + url,'info');
            }
            cometd.websocketEnabled = false;
            cometd.configure({
                url: url,
                requestHeaders: {Authorization: 'OAuth ' + sessionId},
                appendMessageTypeToURL: false,
                logLevel: logLevel
            });
            component.set('v.cometd', cometd);
            helper.addConnectListener(component,event,helper);
            helper.addOnListenerException(component,event,helper);
            helper.addHandshakeListener(component,event,helper);
            helper.handshake(component,event,helper);
        });
        $A.enqueueAction(action);
    },
})