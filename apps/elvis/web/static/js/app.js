
import 'no_bounce'
import 'modernizr'
import {Socket} from 'phoenix'
import Elm from 'Main'
import Raven from 'raven-js'

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
  heartbeatIntervalMs: 1000,
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

channel.on('state', data => {
  broadcasterEvent("startup", data)
})

channel.on('library-add', payload => {
  app.ports.libraryRegistration.send(payload)
})

channel.on('library-response', payload => {
  app.ports.libraryResponse.send(payload)
})

channel.on('receiver-add', payload => {
  broadcasterEvent("receiver-add", payload)
})

channel.on('receiver-remove', payload => {
  broadcasterEvent("receiver-remove", payload)
})

channel.on('receiver-reattach', payload => {
  broadcasterEvent("receiver-reattach", payload)
})

channel.on('receiver-online', payload => {
  broadcasterEvent("receiver-online", payload)
})

channel.on('receiver-rename', payload => {
  broadcasterEvent('receiver-rename', payload)
})

channel.on('receiver-mute', payload => {
  broadcasterEvent('receiver-mute', payload)
})

channel.on('channel-play_pause', payload => {
  broadcasterEvent("channel-play_pause", payload)
})

channel.on('channel-add', payload => {
  broadcasterEvent('channel-add', payload)
})

channel.on('channel-remove', payload => {
  broadcasterEvent('channel-remove', payload)
})

channel.on('channel-rename', payload => {
  broadcasterEvent('channel-rename', payload)
})

channel.on('rendition-progress', payload => {
  broadcasterEvent("rendition-progress", payload)
})

channel.on('rendition-create', payload => {
  broadcasterEvent('rendition-create', payload)
})

channel.on('rendition-active', payload => {
  broadcasterEvent('rendition-active', payload)
})

channel.on('playlist-change', payload => {
  broadcasterEvent("rendition-change", payload)
})

channel.on('volume-change', payload => {
  broadcasterEvent('volume-change', payload)
})

channel.on('settings-application', payload => {
  console.log('settings-application', payload)
  let settings = Object.assign({application: payload.application, saving: false}, {namespaces: payload.settings})
  app.ports.applicationSettings.send([payload.application, settings])
})

channel.join()
.receive('ok', resp => {
  app.ports.connectionStatus.send(true)
  console.log('joined!', resp);
})
.receive('error', resp => { console.error('unable to join', resp); })

// channel.push('list_libraries', {})

let hasTouchEvents = Modernizr.touchevents
let raf = window.requestAnimationFrame || window.webkitRequestAnimationFrame

console.log('touchEvents', hasTouchEvents, Modernizr)

let frame = () => {
	let scroller = document.getElementById('__scrolling__') || document.getElementById('__scrollable__')
	let scrollTop = null
	let height = 0
	if (scroller) {
		scrollTop = hasTouchEvents ? null : scroller.scrollTop
		height = scroller.parentNode.offsetHeight
		// console.log('height', scroller.offsetHeight)
	}
	app.ports.animationScroll.send([Date.now(), scrollTop, height])
	raf(frame)
}

raf(frame)


app.ports.saveState.subscribe(state => {
	console.log('saveState', state)
	localStorage.setItem(savedStateKey, JSON.stringify(state))
})

app.ports.volumeChangeRequests.subscribe(event => {
  channel.push("volume-change", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.receiverMuteRequests.subscribe(event => {
  channel.push("receiver-mute", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.playPauseChanges.subscribe(event => {
  channel.push("channel-play_pause", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.channelNameChanges.subscribe(event => {
  channel.push("channel-rename", event)
  .receive("error", payload => console.log(payload.message))
})
app.ports.receiverNameChanges.subscribe(event => {
  channel.push("receiver-rename", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.channelClearPlaylist.subscribe(event => {
  channel.push("playlist-clear", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.playlistSkipRequests.subscribe(event => {
  channel.push("playlist-skip", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.playlistRemoveRequests.subscribe(event => {
  channel.push("playlist-remove", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.attachReceiverRequests.subscribe(event => {
  channel.push("receiver-attach", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.libraryRequests.subscribe(event => {
  channel.push("library-request", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.addChannelRequests.subscribe(name => {
  console.log("channel-add", name)
  channel.push("channel-add", name)
  .receive("error", payload => console.log(payload.message))
})

app.ports.removeChannelRequests.subscribe(id => {
  channel.push("channel-remove", id)
  .receive("error", payload => console.log(payload.message))
})

app.ports.blurActiveElement.subscribe(blur => {
	if (blur) {
		// http://stackoverflow.com/a/7761438
		document.activeElement.blur();
	}
})

app.ports.settingsRequests.subscribe(app => {
  channel.push("settings-retrieve", app)
  .receive("error", payload => console.log(payload.message))
})

app.ports.settingsSave.subscribe(settings => {
  channel.push("settings-save", settings)
  .receive("error", payload => console.log(payload.message))
})

// the window size signal doesn't always get sent on startup
app.ports.windowWidth.send(window.innerWidth)

// setTimeout(() => {
//   channel.push("retrieve_settings", "otis")
//   .receive("error", payload => console.log(payload.message))
//   .receive("ok", (msg) => console.log('got settings for', 'otis', msg))
// }, 2000)
