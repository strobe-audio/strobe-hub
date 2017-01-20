
import 'no_bounce'
import {Socket} from 'phoenix'
import Elm from 'Main'

let app = Elm.Main.embed(document.getElementById('elm-main'))

let socketOpts = {
  params: {},
  // reconnect attempt every half second. this is sensible/safe behaviour for
  // an app that expects < 5 simultaneous connections
  reconnectAfterMs: () => 500,
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

channel.on('receiver_connected', payload => {
  console.log('receiver_connected', payload)
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
  console.log('library response', payload)
  app.ports.libraryResponse.send(payload)
})

channel.on('channel_added', payload => {
  console.log('new channel', payload)
  app.ports.channelAdditions.send(payload)
})

channel.on('channel_rename', payload => {
  console.log('channel_rename', payload)
  app.ports.channelRenames.send([payload.channelId, payload.name])
})
channel.on('receiver_rename', payload => {
  console.log('receiver_rename', payload)
  app.ports.receiverRenames.send([payload.receiverId, payload.name])
})

channel.join()
.receive('ok', resp => {
  app.ports.connectionStatus.send(true)
  console.log('joined!', resp);
})
.receive('error', resp => { console.error('unable to join', resp); })

// channel.push('list_libraries', {})



app.ports.volumeChangeRequests.subscribe(event => {
  channel.push("change_volume", event)
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
  console.log('library action', event)
  channel.push("library", event)
  .receive("error", payload => console.log(payload.message))
})

app.ports.addChannelRequests.subscribe(name => {
  console.log("add_channel", name)
  channel.push("add_channel", name)
  .receive("error", payload => console.log(payload.message))
})

// the window size signal doesn't always get sent on startup
app.ports.windowWidth.send(window.innerWidth)
