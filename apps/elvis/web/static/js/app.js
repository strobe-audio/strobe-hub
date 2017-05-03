
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

let app = Elm.Main.fullscreen({time, savedState})

let socketOpts = {
  params: {},
  // reconnect attempt every half second. this is sensible/safe behaviour for
  // an app that expects < 5 simultaneous connections
  reconnectAfterMs: () => 250,
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

document.body.onscroll = function(e) {
  // app.ports.scrollTop.send(document.body.scrollTop)
}

channel.on('state', payload => {
  console.log('got startup', payload)
  app.ports.broadcasterState.send(Object.assign({}, payload))
})

channel.on('add_library', payload => {
  console.log('got library', payload);
  app.ports.libraryRegistration.send(payload)
})

channel.on('receiver_removed', payload => {
  console.log('receiver_removed', payload)
  app.ports.receiverStatus.send(['receiver_removed', payload])
})

channel.on('receiver_online', payload => {
  console.log('receiver_online', payload)
  app.ports.receiverPresence.send(payload)
})

channel.on('receiver_added', payload => {
  console.log('receiver_added', payload)
  app.ports.receiverStatus.send(['receiver_added', payload])
})

channel.on('reattach_receiver', payload => {
  console.log('reattach_receiver', payload)
  app.ports.receiverStatus.send(['reattach_receiver', payload])
})

channel.on('channel_play_pause', payload => {
  console.log('channel_play_pause', payload)
  app.ports.channelStatus.send(['channel_play_pause', payload])
})

channel.on('rendition_progress', payload => {
  app.ports.renditionProgress.send(payload)
})

channel.on('rendition_changed', payload => {
  app.ports.renditionChange.send(payload)
})

channel.on('volume_change', payload => {
  app.ports.volumeChange.send(payload)
})

channel.on('new_rendition_created', payload => {
  app.ports.playlistAddition.send(payload)
})

channel.on('library', payload => {
  app.ports.libraryResponse.send(payload)
})

channel.on('channel_added', payload => {
  console.log('new channel', payload)
  app.ports.channelAdditions.send(payload)
})

channel.on('channel_removed', ({id}) => {
  console.log('channel removed', id)
  app.ports.channelRemovals.send(id)
})

channel.on('channel_rename', payload => {
  console.log('channel_rename', payload)
  app.ports.channelRenames.send([payload.channelId, payload.name])
})
channel.on('receiver_rename', payload => {
  console.log('receiver_rename', payload)
  app.ports.receiverRenames.send([payload.receiverId, payload.name])
})
channel.on('receiver_muted', payload => {
  console.log('receiver_muted', payload)
  app.ports.receiverMuting.send([payload.receiverId, payload.muted])
})

channel.on('application_settings', payload => {
  console.log('application_settings', payload)
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
  channel.push("change_volume", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.receiverMuteRequests.subscribe(event => {
  channel.push("mute_receiver", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.playPauseChanges.subscribe(event => {
  channel.push("play_pause", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.channelNameChanges.subscribe(event => {
  channel.push("rename_channel", event)
  .receive("error", payload => console.log(payload.message))
})
app.ports.receiverNameChanges.subscribe(event => {
  channel.push("rename_receiver", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.channelClearPlaylist.subscribe(event => {
  channel.push("clear_playlist", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.playlistSkipRequests.subscribe(event => {
  channel.push("skip_track", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.playlistRemoveRequests.subscribe(event => {
  channel.push("remove_rendition", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.attachReceiverRequests.subscribe(event => {
  channel.push("attach_receiver", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.libraryRequests.subscribe(event => {
  channel.push("library", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.addChannelRequests.subscribe(name => {
  console.log("add_channel", name)
  channel.push("add_channel", name)
  .receive("error", payload => console.log(payload.message))
})

app.ports.removeChannelRequests.subscribe(id => {
  console.log("add_channel", id)
  channel.push("remove_channel", id)
  .receive("error", payload => console.log(payload.message))
})

app.ports.blurActiveElement.subscribe(blur => {
	if (blur) {
		// http://stackoverflow.com/a/7761438
		document.activeElement.blur();
	}
})

app.ports.settingsRequests.subscribe(app => {
  channel.push("retrieve_settings", app)
  .receive("error", payload => console.log(payload.message))
})

app.ports.settingsSave.subscribe(settings => {
  channel.push("save_settings", settings)
  .receive("error", payload => console.log(payload.message))
})

// the window size signal doesn't always get sent on startup
app.ports.windowWidth.send(window.innerWidth)

// setTimeout(() => {
//   channel.push("retrieve_settings", "otis")
//   .receive("error", payload => console.log(payload.message))
//   .receive("ok", (msg) => console.log('got settings for', 'otis', msg))
// }, 2000)
