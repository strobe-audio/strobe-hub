
import {Socket} from 'phoenix'
import Elm from 'Main'

let initialState = {receivers: [], zones: []}
let elmApp = Elm.embed(Elm.Main, document.getElementById('elm-main'), {initialState})

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

channel.on('event', payload => {
	console.log('got event', payload);
})

channel.join()
	.receive('ok', resp => { console.log('joined!', resp); })
	.receive('error', resp => { console.error('unable to join', resp); })

// channel.push('list_libraries', {})



