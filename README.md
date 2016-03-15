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

**Core:**

- [ ] receiver connection keepalive/monitoring. ping-pong messages so that if a
  connection gets cut-off the receiver(s) in question get removed. This could
  just happen periodically on the control connection -- no need to mess with
  audio data delivery. If the control connection goes down then could trigger a
  test of the data connection (if we're playing we'll get quick notification of
  a connection being down...)

- [ ] Wrap all zone pids in Zone struct

- [ ] Fix rebuffering of new receivers

- [ ] move receiver between zones

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

**Nice to have:**

- [ ] Look at protocols for adding of albums in a single step (would love to have
  the UI show an album in the source list, which I think involves native
  support for groups of tracks as entries in source lists)

[simple TCP sockets]: http://stackoverflow.com/questions/4081502/sending-raw-binary-using-tcp-in-erlang

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


