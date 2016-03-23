
import {Socket} from 'phoenix'
import Elm from 'Main'

// app initial state
let initialState = {receivers: [], zones: [], sources: []}

// port initial state
let receiverStatus = ["", {event: "", receiverId: "", zoneId: ""}]
let zoneStatus = ["", {event: "", zoneId: "", status: ""}]
let sourceProgress = {zoneId: "", sourceId: "", progress: 0, duration: 0}
let portValues = {initialState, receiverStatus, zoneStatus, sourceProgress}

let elmApp = Elm.embed(Elm.Main, document.getElementById('elm-main'), portValues)

let socket = new Socket("/controller", {params: {}})

socket.connect();

let channel = socket.channel('controllers:browser', {})

channel.on('state', payload => {
	console.log('got startup', payload)
	elmApp.ports.initialState.send(payload)
})

channel.on('add_library', payload => {
	console.log('got library', payload);
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

channel.join()
	.receive('ok', resp => { console.log('joined!', resp); })
	.receive('error', resp => { console.error('unable to join', resp); })

// channel.push('list_libraries', {})



elmApp.ports.volumeChanges.subscribe(event => {
  channel.push("change_volume", event)
         .receive("error", payload => console.log(payload.message))
})

elmApp.ports.playPauseChanges.subscribe(event => {
	console.log('play pause change', event)
  channel.push("play_pause", event)
         .receive("error", payload => console.log(payload.message))
})
