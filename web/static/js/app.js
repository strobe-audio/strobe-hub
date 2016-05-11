
import {Socket} from 'phoenix'
import Elm from 'Main'

let uiState = {
  channels: [],
  receivers: [],
}

// app initial state
let broadcasterState = {
  receivers: [],
  channels: [],
  sources: [],
}

// port initial state
let receiverStatus = ["", {event: "", receiverId: "", channelId: ""}]
let channelStatus = ["", {event: "", channelId: "", status: ""}]
let sourceProgress = {channelId: "", sourceId: "", progress: 0, duration: 0}
let sourceChange = {channelId: "", removeSourceIds: []}
let volumeChange = {id: "", target: "", volume: 0.0}
let metadata = { bit_rate: 0
  , channels:     0
  , duration_ms:  0
  , extension:    ""
  , filename:     ""
  , mime_type:    ""
  , sample_rate:  0
  , stream_size:  0
  , album:        ""
  , composer:     ""
  , date:         ""
  , disk_number:  0
  , disk_total:   0
  , genre:        ""
  , performer:    ""
  , title:        ""
  , track_number: 0
  , track_total:  0
}
let playlistAddition = { id: "", position: 0, playbackPosition: 0, sourceId: "", channelId: "" , source: { id: "", metadata: metadata}}
let folder = { id: "", title: "", icon: "", action: "", children: []}
let libraryRegistration = { id: "", title: "", icon: "", action: "" }
let libraryResponse = { libraryId: "", folder}
let windowWidth = window.innerWidth
let channelAdditions = { id: "", name: "", position: 0, volume: 0.0, playing: false }
let channelRenames = ["", ""]

let portValues = {
  broadcasterState,
  receiverStatus,
  channelStatus,
  sourceProgress,
  sourceChange,
  volumeChange,
  playlistAddition,
  libraryRegistration,
  libraryResponse,
  windowWidth,
  channelAdditions,
  channelRenames,
}

let elmApp = Elm.embed(Elm.Main, document.getElementById('elm-main'), portValues)

let socket = new Socket("/controller", {params: {}})

socket.connect();

let channel = socket.channel('controllers:browser', {})

channel.on('state', payload => {
  console.log('got startup', payload)
  elmApp.ports.broadcasterState.send(Object.assign({}, payload))
})

channel.on('add_library', payload => {
  console.log('got library', payload);
  elmApp.ports.libraryRegistration.send(payload)
})

channel.on('receiver_removed', payload => {
  console.log('receiver_removed', payload)
  elmApp.ports.receiverStatus.send(['receiver_removed', payload])
})

channel.on('receiver_added', payload => {
  console.log('receiver_added', payload)
  elmApp.ports.receiverStatus.send(['receiver_added', payload])
})

channel.on('reattach_receiver', payload => {
  console.log('reattach_receiver', payload)
  elmApp.ports.receiverStatus.send(['reattach_receiver', payload])
})

channel.on('channel_play_pause', payload => {
  console.log('channel_play_pause', payload)
  elmApp.ports.channelStatus.send(['channel_play_pause', payload])
})

channel.on('source_progress', payload => {
  elmApp.ports.sourceProgress.send(payload)
})

channel.on('source_changed', payload => {
  elmApp.ports.sourceChange.send(payload)
})

channel.on('volume_change', payload => {
  elmApp.ports.volumeChange.send(payload)
})

channel.on('new_source_created', payload => {
  elmApp.ports.playlistAddition.send(payload)
})

channel.on('library', payload => {
  console.log('library response', payload)
  elmApp.ports.libraryResponse.send(payload)
})

channel.on('channel_added', payload => {
  console.log('new channel', payload)
  elmApp.ports.channelAdditions.send(payload)
})

channel.on('channel_rename', payload => {
  console.log('channel_rename', payload)
  elmApp.ports.channelRenames.send([payload.channelId, payload.name])
})

channel.join()
.receive('ok', resp => { console.log('joined!', resp); })
.receive('error', resp => { console.error('unable to join', resp); })

// channel.push('list_libraries', {})



elmApp.ports.volumeChangeRequests.subscribe(event => {
  channel.push("change_volume", event)
  .receive("error", payload => console.log(payload.message))
})

elmApp.ports.playPauseChanges.subscribe(event => {
  channel.push("play_pause", event)
  .receive("error", payload => console.log(payload.message))
})

elmApp.ports.channelNameChanges.subscribe(event => {
  channel.push("rename_channel", event)
  .receive("error", payload => console.log(payload.message))
})

elmApp.ports.playlistSkipRequests.subscribe(event => {
  channel.push("skip_track", event)
  .receive("error", payload => console.log(payload.message))
})

elmApp.ports.attachReceiverRequests.subscribe(event => {
  channel.push("attach_receiver", event)
  .receive("error", payload => console.log(payload.message))
})

elmApp.ports.libraryRequests.subscribe(event => {
  console.log('library action', event)
  channel.push("library", event)
  .receive("error", payload => console.log(payload.message))
})

elmApp.ports.addChannelRequests.subscribe(name => {
  console.log("add_channel", name)
  channel.push("add_channel", name)
  .receive("error", payload => console.log(payload.message))
})

// the window size signal doesn't always get sent on startup
elmApp.ports.windowWidth.send(window.innerWidth)
