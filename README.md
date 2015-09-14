Peep
====

Synchronised Player
-------------------

- http://stackoverflow.com/questions/2795031/synchronizing-audio-over-a-network
- http://stackoverflow.com/questions/598778/how-to-synchronize-media-playback-over-an-unreliable-network
- http://research.microsoft.com/apps/pubs/default.aspx?id=65146
- http://snarfed.org/synchronizing_mp3_playback

- set up sntp with the broadcaster as the server?


- Player is Elixir
- Use the [NTP algo][] to find the difference between server 'time' (`:erlang.monotonic_time :milli_seconds`) and client time
- Streaming packets are sent as erlang messages over the network, or over a socket with serialization (if messages doesn't cut it)
- Packets have form: `{:frame, <time_to_play_at>, << data >>}` where:
    - `time_to_play_at` is the `monotonic_time` on the server that this packet should be played at

- I could try using `/dev/audio` to play the PCM stream which could avoid issues with buffering in the players

[NTP algo]: http://www.ntp.org/ntpfaq/NTP-s-algo.htm#Q-ALGO-BASIC-SYNC

TODO
----

- [ ] automatically add player to zone once it's online & synced
- [ ] play a startup sound to boot audio hardware when janis comes online

Bugs
----

- [ ] can't read aac files (m4a). Replace sox with avconv/ffmpeg (see here re [converting to raw/pcm][])
- [x] adding sources to a source stream after all sources have played won't start again
- [ ] can't replay a source
- [ ] zone should call audio stream for most api functions

[converting to raw/pcm]: http://stackoverflow.com/questions/4854513/can-ffmpeg-convert-audio-to-raw-pcm-if-so-how

Time Sync
=========

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

It's not feasible to re-implement the PTP system in Erlang/Elixir - too big a
job and it just doesn't have the primitives (e.g. low-level access to network
stack).

*BUT* precision time sync is vital...

[Precise Time Protocol]: http://sourceforge.net/p/ptpd/wiki/Home/

NTP
---

Or, alternatively, we could use GPS as a time source. This is extremely accurate (of the order of tens of **nanoseconds**) but requires additional hardware costs of ~30 quid or so

Link dump:


- http://www.ehow.com/about_5073608_accurate-gps-time.html
- http://blog.retep.org/2012/06/18/getting-gps-to-work-on-a-raspberry-pi/
- https://www.sparkfun.com/pages/GPS_Guide


UDP
---

- http://zentrope.tumblr.com/post/149688423/erlang-multicast-presencediscovery-notification

server:

    {:ok, socket} = :gen_udp.open 0, ip: {0, 0, 0, 0}, multicast_ttl: 255

    :gen_udp.send socket,  {239,0,0,251}, 6666, <<"hello">>

client:

    {:ok, socket} = :gen_udp.open 6666, [:binary, active: true, ip: {239,0,0,251}, add_membership: {{239,0,0,251}, {0, 0, 0, 0}}, reuseaddr: true]

    receive do; msg -> msg; end


