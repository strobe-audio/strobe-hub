Peep
====

What is the aim?
----------------

Something to replace LMS.

- Raspberry Pi oriented.
- Download images for server & client
- Zero config of client - disposable, re-installable
- Plug in drives of Music
- Extendable through plugins

DLNA
====

Be a dlna renderer? dlna for music management.
Twonky (dead)

dlna server -> music library?

e.g. connect NAS music library to peep over dlna protocol -- no need for music import

Dependencies
------------

    brew install mediainfo
    brew install libav

Synchronised Player
-------------------

- http://stackoverflow.com/questions/2795031/synchronizing-audio-over-a-network
- http://stackoverflow.com/questions/598778/how-to-synchronize-media-playback-over-an-unreliable-network
- http://research.microsoft.com/apps/pubs/default.aspx?id=65146
- http://snarfed.org/synchronizing_mp3_playback

- set up sntp with the broadcaster as the server?


- Player is Elixir
- Use the [NTP algo][] to find the difference between server 'time' and client time
- Packets have form: `{:frame, <time_to_play_at>, << data >>}` where:
    - `time_to_play_at` is the `monotonic_time` on the server that this packet should be played at


[NTP algo]: http://www.ntp.org/ntpfaq/NTP-s-algo.htm#Q-ALGO-BASIC-SYNC

TODO
----

So much.

**BUGS**:

- [ ] Fix janis crash when connecting over vpn:
      ```
      2016-03-07 21:56:33.778  [error] GenServer Otis.DNSSD terminating
      ** (MatchError) no match of right hand side value: nil
      (janis) lib/janis/network.ex:24: Janis.Network.best_ip/2
      (janis) lib/janis/broadcaster.ex:66: Janis.Broadcaster.new/3
      (janis) lib/janis/broadcaster.ex:28: Janis.Broadcaster.start_broadcaster/4
      (janis) lib/janis/dnssd.ex:32: Janis.DNSSD.handle_info/2
      ```
- [ ] SourceList.clear doesn't send any events or delete any sources from the db

- [ ] 'Progress event for unknown source' -- why?

      ```
      2016-03-15 12:27:07.060 [info]  SOURCE CHANGED f32db771-39b4-4992-954d-0bf1b616d2fa => f4449b2e-60c3-49a8-9e0d-19285602ffbe
      2016-03-15 12:27:07.060 [info]  SOURCE CHANGED f4449b2e-60c3-49a8-9e0d-19285602ffbe => f32db771-39b4-4992-954d-0bf1b616d2fa
      2016-03-15 12:27:07.060 [warn]  Late emitter: emit time (ms): -547.68; packet play in (ms): 1378
      2016-03-15 12:27:07.060 [warn]  Late emitter: emit time (ms): -447.84; packet play in (ms): 1478
      2016-03-15 12:27:07.061 [warn]  Late emitter: emit time (ms): -349.12; packet play in (ms): 1576
      2016-03-15 12:27:07.062 [warn]  Late emitter: emit time (ms): -249.84; packet play in (ms): 1676
      2016-03-15 12:27:07.062 [warn]  deleting source "f32db771-39b4-4992-954d-0bf1b616d2fa"
      2016-03-15 12:27:07.206 [info]  EVENT: {:source_changed, "f058c281-9186-4585-81f5-b61399c8c729", "f32db771-39b4-4992-954d-0bf1b616d2fa", "f4449b2e-60c3-49a8-9e0d-19285602ffbe"}
      2016-03-15 12:27:07.207 [warn]  deleting source "f4449b2e-60c3-49a8-9e0d-19285602ffbe"
      2016-03-15 12:27:07.208 [info]  SOURCE CHANGED f32db771-39b4-4992-954d-0bf1b616d2fa => f4449b2e-60c3-49a8-9e0d-19285602ffbe
      2016-03-15 12:27:07.345 [info]  EVENT: {:source_changed, "f058c281-9186-4585-81f5-b61399c8c729", "f4449b2e-60c3-49a8-9e0d-19285602ffbe", "f32db771-39b4-4992-954d-0bf1b616d2fa"}
      2016-03-15 12:27:07.346 [error] Progress event for unknown source "f4449b2e-60c3-49a8-9e0d-19285602ffbe" (400)
      2016-03-15 12:27:07.356 [error] Progress event for unknown source "f32db771-39b4-4992-954d-0bf1b616d2fa" (451100)
      2016-03-15 12:27:07.360 [info]  EVENT: {:old_source_removed, "f32db771-39b4-4992-954d-0bf1b616d2fa"}
      2016-03-15 12:27:07.361 [warn]  deleting source "f32db771-39b4-4992-954d-0bf1b616d2fa"
      2016-03-15 12:27:07.381 [info]  EVENT: {:source_changed, "f058c281-9186-4585-81f5-b61399c8c729", "f32db771-39b4-4992-954d-0bf1b616d2fa", "f4449b2e-60c3-49a8-9e0d-19285602ffbe"}
      2016-03-15 12:27:07.385 [info]  EVENT: {:old_source_removed, "f4449b2e-60c3-49a8-9e0d-19285602ffbe"}
      2016-03-15 12:27:07.385 [info]  EVENT: {:old_source_removed, "f32db771-39b4-4992-954d-0bf1b616d2fa"}
      ```

- [ ] Whole zone crashes when porcelain/goon crashes:

```
panic: write |1: broken pipe

goroutine 3 [running]:
runtime.panic(0xa4ba0, 0xc21001f570)
/usr/local/Cellar/go/1.2.2/libexec/src/pkg/runtime/panic.c:266 +0xb6
log.(*Logger).Panicf(0xc210020190, 0xde260, 0x3, 0x40fe38, 0x1, ...)
/usr/local/Cellar/go/1.2.2/libexec/src/pkg/log/log.go:200 +0xbd
main.fatal_if(0xc2840, 0xc2100365a0)
/Users/alco/extra/goworkspace/src/goon/util.go:38 +0x17e
main.inLoop2(0x257338, 0xc210036390, 0xc21000a280, 0x2572c0, 0xc210000000, ...)
/Users/alco/extra/goworkspace/src/goon/io.go:100 +0x5ce
created by main.wrapStdin2
/Users/alco/extra/goworkspace/src/goon/io.go:25 +0x15a

goroutine 1 [runnable]:
main.proto_2_0(0x7fff5fbf0101, 0xe3fc0, 0x3, 0xde7a0, 0x1, ...)
/Users/alco/extra/goworkspace/src/goon/proto_2_0.go:58 +0x3a3
main.main()
/Users/alco/extra/goworkspace/src/goon/main.go:51 +0x3b6

2016-03-16 21:08:40.014  [error] Process #PID<0.1373.0> raised an exception
** (ArgumentError) argument error
  :erlang.port_command(#Port<0.28586>, [])

2016-03-16 21:08:44.927  [error] GenServer #PID<0.755.0> terminating
** (FunctionClauseError) no function clause matching in Otis.Zone.BufferedStream.handle_info/2
    (otis) lib/otis/zone/buffered_stream.ex:86: Otis.Zone.BufferedStream.handle_info({:DOWN, #Reference<0.0.6.394>, :process, #PID<0.756.0>, {:timeout, {GenServer, :call, [#PID<0.754.0>, :frame, 5000]}}}, %Otis.Zone.BufferedStream{audio_stream: #PID<0.754.0>, buffering: false, fetcher: #PID<0.756.0>, packets: 2, queue: {[%Otis.Packet{data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>, duration_ms: 451257, emitter: nil, offset_ms: 451100, packet_number: 0, packet_size: 17640, source_id: "f629e13a-6182-4356-a5ba-395a79bad9d9", source_index: 4511, timestamp: 0}], [%Otis.Packet{data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>, duration_ms: 451257, emitter: nil, offset_ms: 451000, packet_number: 0, packet_size: 17640, source_id: "f629e13a-6182-4356-a5ba-395a79bad9d9", source_index: 4510, timestamp: 0}]}, size: 10, state: :playing, task: nil, waiting: {#PID<0.776.0>, #Reference<0.0.5505026.87698>}})
    (stdlib) gen_server.erl:615: :gen_server.try_dispatch/4
    (stdlib) gen_server.erl:681: :gen_server.handle_msg/5
    (stdlib) proc_lib.erl:240: :proc_lib.init_p_do_apply/3
Last message: {:DOWN, #Reference<0.0.6.394>, :process, #PID<0.756.0>, {:timeout, {GenServer, :call, [#PID<0.754.0>, :frame, 5000]}}}
State: %Otis.Zone.BufferedStream{audio_stream: #PID<0.754.0>, buffering: false, fetcher: #PID<0.756.0>, packets: 2, queue: {[%Otis.Packet{data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>, duration_ms: 451257, emitter: nil, offset_ms: 451100, packet_number: 0, packet_size: 17640, source_id: "f629e13a-6182-4356-a5ba-395a79bad9d9", source_index: 4511, timestamp: 0}], [%Otis.Packet{data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>, duration_ms: 451257, emitter: nil, offset_ms: 451000, packet_number: 0, packet_size: 17640, source_id: "f629e13a-6182-4356-a5ba-395a79bad9d9", source_index: 4510, timestamp: 0}]}, size: 10, state: :playing, task: nil, waiting: {#PID<0.776.0>, #Reference<0.0.5505026.87698>}}
2016-03-16 21:08:44.929  [error] GenServer #PID<0.776.0> terminating
** (stop) exited in: GenServer.call(#PID<0.755.0>, :frame, 5000)
    ** (EXIT) time out
    (elixir) lib/gen_server.ex:564: GenServer.call/3
    (otis) lib/otis/zone/broadcaster.ex:369: Otis.Zone.Broadcaster.next_packet/4
    (otis) lib/otis/zone/broadcaster.ex:218: Otis.Zone.Broadcaster.send_next_packet/1
    (otis) lib/otis/zone/broadcaster.ex:197: Otis.Zone.Broadcaster.potentially_emit/2
    (otis) lib/otis/zone/broadcaster.ex:89: Otis.Zone.Broadcaster.handle_cast/2
    (stdlib) gen_server.erl:615: :gen_server.try_dispatch/4
    (stdlib) gen_server.erl:681: :gen_server.handle_msg/5
    (stdlib) proc_lib.erl:240: :proc_lib.init_p_do_apply/3
Last message: {:"$gen_cast", {:emit, 25000}}

    ** (EXIT) time out
    (elixir) lib/gen_server.ex:564: GenServer.call/3
    (otis) lib/otis/audio_stream.ex:84: Otis.AudioStream.audio_frame/1
    (otis) lib/otis/audio_stream.ex:54: Otis.AudioStream.handle_call/3
    (stdlib) gen_server.erl:629: :gen_server.try_handle_call/4
    (stdlib) gen_server.erl:661: :gen_server.handle_msg/5
    (stdlib) proc_lib.erl:240: :proc_lib.init_p_do_apply/3
Last message: :frame
State: %Otis.AudioStream.S{buffer: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>, packet: %Otis.Packet{data: nil, duration_ms: 451257, emitter: nil, offset_ms: 451200, packet_number: 0, packet_size: 17640, source_id: "f629e13a-6182-4356-a5ba-395a79bad9d9", source_index: 4512, timestamp: 0}, packet_size: 17640, source_list: #PID<0.751.0>, state: :playing, stream: #PID<0.1350.0>}
```

**Core:**

- [ ] receiver connection keepalive/monitoring. ping-pong messages so that if a
  connection gets cut-off the receiver(s) in question get removed. This could
  just happen periodically on the control connection -- no need to mess with
  audio data delivery. If the control connection goes down then could trigger a
  test of the data connection (if we're playing we'll get quick notification of
  a connection being down...)

- [ ] Wrap all zone pids in Zone struct

- [ ] No way of getting the currently playing track... Should be a method on
  the zone. In fact the current source list behaviour needs work. The current
  song is popped off the source list when played, so it only exists in the db
  and the zone process. But on re-start un-finished songs just pop back to the
  top of the source-list. Gotta think of a consistent way to deal with this.

- [ ] Move all source list manipulations into the zone

- [ ] zones stop when all receievers removed

- [ ] rename `Zone` to `Channel` or `Station` -- zones are just static
  pre-configured playlists. 'zone' is geographic but we want to think of the
  setup more like 'tuning in' to a particular playlist -- more like a radio
  station than a room. Want to think of the 'zone' system as a way to keep a
  set of playlists -- we should be light about them -- it's ok to keep loads
  (say as a way to pop ideas for songs to play later) and then drop some number
  of receivers on to them to listen.

- [ ] move source list entries between zones

- [x] use `Ecto.UUID` for all ids in `Otis.State` -- currently we're on
  `:string` but I think this is a mistake
- [x] replace phoenix websocket connection with raw TCP for control messages
- [x] better receiver behaviour when broadcaster drops out (currently the processes
  don't crash until the timesync times-out)
- [x] replace nanomsg with [simple TCP sockets]
- [x] Last source in the zone doesn't get deleted from the db. We get a
  `zone_finished` message but no `source_finished` equivalent. Could issue a
  `{:source_changed, "<zone_id>", "<source_id>", nil}` at the end to mirror the
  `{:source_changed, "<zone_id>", nil, "<source_id>"}` at the beginning.
- [x] Replace `SourceList.append_source` and `SourceList.append_sources` with
  `SourceList.append`
- [x] Leaking SourceStream processes (can return `{stop,Reason,Reply,NewState}`
  from `next_chunk`)
- [x] Playback progress.
- [x] Zone.skip doesn't delete the source db entry for the currently playing source
- [x] Crash attempting to play a zone with no attached receivers
- [x] Fix rebuffering of new receivers
- [x] move receiver between zones
- [x] what happens if a receiver tcp process crashes? The recevier process
  should get torn down, both the tcp conns closed and the real recevier should
  try to re-connect...
  ```
  {:ok, %{data: {pid, port}} = r1} = Otis.Receivers.receiver "626de8c0-b0ea-5ea4-bb63-48f55fee70fa"
  Process.exit pid, :kill
  ```

**Nice to have:**

- [ ] Look at protocols for adding of albums in a single step (would love to have
  the UI show an album in the source list, which I think involves native
  support for groups of tracks as entries in source lists)

[simple TCP sockets]: http://stackoverflow.com/questions/4081502/sending-raw-binary-using-tcp-in-erlang

New Receiver re-buffering
-------------------------

Buffering of new receivers is hit and miss -- I can try to send as many un-played
packets as possible but the sending of 'real' packets interferes with this.

What I need (I think) is some kind of per-receiver packet queue that makes sure
that packets are received by the receiver in-order. That way I can flood-send
old (but unplayed) packets as part of the receiver-join routine and this queue
mechanism will ensure that they get to the receiver in the right order, rather
than the real audio packets potentially getting there before their earlier siblings.

This is a big change -- I would need to be monitoring the receivers queue(s) for
packets to emit, rather than the broadcaster.

The queue would have to manage emission times, based on the play times.


UI
--

### Clojurescript?

- [re-frame](https://github.com/Day8/re-frame)

Pros:

- interesting ecosystem, full of ideas
- purely functional like the backend

Cons:

- clojurescript! I hate lisps.


### React+redux+mori

- https://github.com/reactjs/redux
- http://swannodette.github.io/mori/ - gives me all the enum goodness

Pros:

- I'll be much more productive - webpack, es2015 etc are things I know
- Easier access to things like react-canvas (I will have loong lists of things
  to render)

Cons:

- Not as interesting technically

Ideas
-----

Reduce memory usage by sending out some kind of 'sleep' command to all players when:

- no audio is playing
- the ui hasn't been used for n minutes

This sleep state could be as simple as pausing the audio stream. WIth no packets to emit the receivers aren't actually doing much apart from time-sync.

UDP Multicast Problems
----------------------

UDP multicast across a wifi-wired bridge is not reliable.

http://superuser.com/questions/730288/why-do-some-wifi-routers-block-multicast-packets-going-from-wired-to-wireless

Simplest solution would be to exclusively use TCP streams for the audio.

Getting music onto the server
-----------------------------

WebDAV is a good solution. Mounts natively in windows & mac and Yaws does it out of the box: http://yaws.hyber.org/

Sound File metadata
-------------------

Need to be able to extract metadata (album, artist etc) from sound files. Don't want to re-implement this in Elixir, it's just annoying.

Ideas:

- http://www.mega-nerd.com/libsndfile/api.html "Functions for Reading and Writing String Data". Write a quick erlang wrapper around the required bits of the api (not a nif or anything else that might crash the vm... http://www.erlang.org/doc/tutorial/erl_interface.html)

### Need to extract cover art

Bugs
----

- [ ] zone should call audio stream for most api functions


Time Sync
=========

**The sync as done in elixir is actually more than good enough**

It would be good to more to a more precise time sync system e.g. [Precise Time Protocol][] (PTP).

The problems with this are:

- It probably needs to run all the time to work but we want to allow for
  players to be turned off when they're not in use (or rather, not discourage
  people from doing that)
- Launching a completely separate daemon with a whole bunch of config
  implications is not trivial. It would change the server requirements from an
  "app" like approach to a more system level software installation (e.g. a
  leveraging the local package management system to install & configure
  dependencies or require the use of Docker)

- https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Deployment_Guide/s1-Using_PTP.html

It would be possible to approximate the core actions of PTP in elixir/erlang.

Using https://github.com/travelping/gen_socket I can get low-level access to
sockets and actually apply `SO_TIMESTAMP` behaviour -- this will get rid of a
major source of error in the current latency calculations (which are currently
~30us off on localhost, probably much more on WiFi).

Wikipedia has a good overview of the protocol, which actually isn't that far off
what I'm already doing.

[Precise Time Protocol]: http://sourceforge.net/p/ptpd/wiki/Home/

NTP
---

Or, alternatively, we could use GPS as a time source. This is extremely accurate (of the order of tens of **nanoseconds**) but requires additional hardware costs of ~30 quid or so

Link dump:


- http://www.ehow.com/about_5073608_accurate-gps-time.html
- http://blog.retep.org/2012/06/18/getting-gps-to-work-on-a-raspberry-pi/
- https://www.sparkfun.com/pages/GPS_Guide


