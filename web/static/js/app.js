
import {Socket} from 'phoenix'
import Elm from 'Main'

let uiState = {
  zones: [],
  receivers: [],
}
// app initial state
let initialState = {
  receivers: [],
  zones: [],
  sources: [],
  libraries: [],
  ui: uiState,
}

// port initial state
let receiverStatus = ["", {event: "", receiverId: "", zoneId: ""}]
let zoneStatus = ["", {event: "", zoneId: "", status: ""}]
let sourceProgress = {zoneId: "", sourceId: "", progress: 0, duration: 0}
let sourceChange = {zoneId: "", removeSourceIds: []}
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
let playlistAddition = { id: "", position: 0, playbackPosition: 0, sourceId: "", zoneId: "" , source: { id: "", metadata: metadata}}
let folder = { id: "", title: "", icon: "", action: "", children: []}
let libraryRegistration = { name: "", id: "", levels: [], level: folder, action: "" }
let libraryResponse = { libraryId: "", folder}

let portValues = {
	initialState,
	receiverStatus,
	zoneStatus,
	sourceProgress,
	sourceChange,
	volumeChange,
	playlistAddition,
	libraryRegistration,
	libraryResponse,
}

let elmApp = Elm.embed(Elm.Main, document.getElementById('elm-main'), portValues)

let socket = new Socket("/controller", {params: {}})

socket.connect();

let channel = socket.channel('controllers:browser', {})

channel.on('state', payload => {
	console.log('got startup', payload)
	elmApp.ports.initialState.send(Object.assign({}, payload, {ui: uiState, libraries: []}))
})

channel.on('add_library', payload => {
	console.log('got library', payload);
	elmApp.ports.libraryRegistration.send(Object.assign({}, libraryRegistration, payload))
})

channel.on('receiver_removed', payload => {
	console.log('receiver_removed', payload)
	elmApp.ports.receiverStatus.send(['receiver_removed', payload])
})

channel.on('receiver_added', payload => {
	console.log('receiver_added', payload)
	elmApp.ports.receiverStatus.send(['receiver_added', payload])
})

channel.on('zone_play_pause', payload => {
	console.log('zone_play_pause', payload)
	elmApp.ports.zoneStatus.send(['zone_play_pause', payload])
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
