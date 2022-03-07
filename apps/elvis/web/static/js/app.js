/*eslint no-console: ["warn", { allow: ["warn", "error"] }] */

import 'no_bounce'
import 'modernizr'
import {Socket} from 'phoenix'
import Elm from 'Main'
import Raven from 'raven-js'
import Pressure from 'pressure'


if (window.SENTRY_DSN) {
  console.log('Installing Sentry error tracking...')
  Raven.config(window.SENTRY_DSN).install()
}

// change the state key in the case of 'schema' changes
const savedStateKey = 'elvis-stored-state-20160124-02'
let storedState = localStorage.getItem(savedStateKey)
let savedState = storedState ? JSON.parse(storedState) : null
let time = Date.now()

let app = Elm.Main.fullscreen({time, windowInnerWidth: window.innerWidth, savedState})

let socketOpts = {
  params: {},
  // reconnect attempt every 100ms. this is sensible/safe behaviour for
  // an app that expects < 5 simultaneous connections
  reconnectAfterMs: () => 100,
  rejoinAfterMs: () => 100,
  heartbeatIntervalMs: 2000,
  // logger: (kind, msg, data) => console.log(`${kind}: ${msg}`, data),
}
let socket = new Socket("/controller", socketOpts)

socket.onOpen(() =>{
  // app.ports.connectionStatus.send(true)
})
socket.onClose(() =>{
  app.ports.connectionStatus.send(false)
})
socket.onError(() =>{
  app.ports.connectionStatus.send(false)
})

socket.connect();

let channel = socket.channel('controllers:browser', {})

document.body.onscroll = function() {
  // app.ports.scrollTop.send(document.body.scrollTop)
}

function broadcasterEvent(type, data) {
  app.ports.broadcasterEvent.send(Object.assign({__type__: type}, data))
}

function forward(channel, type, msgType) {
  channel.on(type, payload => {
    broadcasterEvent(msgType || type, payload)
  })
}

channel.on('state', data => {
  broadcasterEvent("startup", data)
})

channel.on('library-add', payload => {
  app.ports.libraryRegistration.send(payload)
})

channel.on('library-response', payload => {
  app.ports.libraryResponse.send(payload)
})


forward(channel, 'receiver-add')
forward(channel, 'receiver-remove')
forward(channel, 'receiver-reattach')
forward(channel, 'receiver-online')
forward(channel, 'receiver-rename')
forward(channel, 'receiver-mute')

forward(channel, 'channel-play_pause')
forward(channel, 'channel-add')
forward(channel, 'channel-remove')
forward(channel, 'channel-rename')

forward(channel, 'rendition-progress')
forward(channel, 'rendition-create')
forward(channel, 'rendition-active')

forward(channel, 'playlist-change')

forward(channel, 'volume-change')

channel.on('settings-application', payload => {
  let settings = Object.assign({
    application: payload.application,
    saving: false
  }, {
    namespaces: payload.settings,
  })
  app.ports.applicationSettings.send([payload.application, settings])
})

// set on body because it's likely that at this point our UI has not been built
Pressure.set('body', {
  change(force) {
    if (force >= 1.0) {
      app.ports.forcePress.send(true)
    } else {
      app.ports.forcePress.send(false)
    }
  },
  unsupported() {
    console.warn('Pressure unsupported')
  }
}, {polyfill: false})

function push(channel, event, payload) {
  channel.push(event, payload).receive("error", resp => {
    console.error(resp.message)
  })
}

function subscription(app, portName, channel, name) {
  app.ports[portName].subscribe(payload => push(channel, name, payload))
}

subscription(app, 'volumeChangeRequests', channel, "volume-change")
subscription(app, 'receiverMuteRequests', channel, "receiver-mute")
subscription(app, 'receiverNameChanges', channel, "receiver-rename")
subscription(app, 'attachReceiverRequests', channel, "receiver-attach")
subscription(app, 'channelClearPlaylist', channel, "playlist-clear")
subscription(app, 'playlistSkipRequests', channel, "playlist-skip")
subscription(app, 'playlistRemoveRequests', channel, "playlist-remove")
subscription(app, 'playPauseChanges', channel, "channel-play_pause")
subscription(app, 'channelNameChanges', channel, "channel-rename")
subscription(app, 'addChannelRequests', channel, "channel-add")
subscription(app, 'removeChannelRequests', channel, "channel-remove")
subscription(app, 'settingsRequests', channel, "settings-retrieve")
subscription(app, 'settingsSave', channel, "settings-save")
subscription(app, 'libraryRequests', channel, "library-request")

app.ports.saveState.subscribe(state => {
  localStorage.setItem(savedStateKey, JSON.stringify(state))
})

app.ports.blurActiveElement.subscribe(blur => {
  if (blur) {
    // http://stackoverflow.com/a/7761438
    document.activeElement.blur();
  }
})

// the window size signal doesn't always get sent on startup
app.ports.windowWidth.send(window.innerWidth)

channel.join().receive('ok', () => {
  app.ports.connectionStatus.send(true)
}).receive('error', resp => {
  console.error('unable to join', resp)
})

let hasTouchEvents = Modernizr.touchevents
let _requestAnimationFrame = window.requestAnimationFrame || window.webkitRequestAnimationFrame

let frame = () => {
  let scroller = document.getElementById('__scrolling__') || document.getElementById('__scrollable__')
  let scrollTop = null
  let height = 0
  if (scroller) {
    scrollTop = hasTouchEvents ? null : scroller.scrollTop
    height = scroller.parentNode.offsetHeight
  }
  app.ports.animationScroll.send([Date.now(), scrollTop, height])
  _requestAnimationFrame(frame)
}

_requestAnimationFrame(frame)
