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
- Use the [NTP algo][] to find the difference between server 'time' (`:erlang.monotonic_time :milli_seconds`) and client time
- Streaming packets are sent as erlang messages over the network, or over a socket with serialization (if messages doesn't cut it)
- Packets have form: `{:frame, <time_to_play_at>, << data >>}` where:
    - `time_to_play_at` is the `monotonic_time` on the server that this packet should be played at

- I could try using `/dev/audio` to play the PCM stream which could avoid issues with buffering in the players

[NTP algo]: http://www.ntp.org/ntpfaq/NTP-s-algo.htm#Q-ALGO-BASIC-SYNC

TODO
----

- [x] automatically add player to zone once it's online & synced
- [ ] tell next source in list to prepare (e.g. open files etc) to ensure seamless playback
- [ ] make janis sockets understand some commands:
      - [ ] "flsh" i.e. "flush". Discard any unplayed packets that you have
      - [ ] "stop". Doesn't do anything at present but could be used to switch to a lower-power state
            i.e. stop the broadcaster process looping
- [ ] implement 'skip' etc as a broadcaster flush + stop and launch new broadcaster


- broadcast at 48000 sample rate (a la DVD)? Why?
  - http://forum.doom9.org/archive/index.php/t-131642.html
  - http://shibatch.sourceforge.net/

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

But, if we can find a way to detect if UDP multicast between the broadcaster and a specific receiver works (which shouldn't be too hard really) then we can start to do more intelligent things:

- if the UDP multicast doesn't work then fallback to a TCP stream for the receiver

or, for extra points:

work out the UDP multicast connectivity between all nodes (peer to peer). This would allow us to group them into UDP-multicast-able pools. Say for a mixed wifi-wired network there would probably be two pools: the receivers on wifi and those on ethernet.

Assuming that the broadcaster belongs to one of those pools then we need to bridge UDP across to the other(s).

If the receivers in a pool (different from the broadcaster) elect a leader (using raft e.g.) then the broadcaster could use TCP to stream to it (accross the UDP divide) and then it could re-transmit the data to the other receivers in its pool using UDP multicast.

Sound File metadata
-------------------

Need to be able to extract metadata (album, artist etc) from sound files. Don't want to re-implement this in Elixir, it's just annoying.

Ideas:

- http://www.mega-nerd.com/libsndfile/api.html "Functions for Reading and Writing String Data". Write a quick erlang wrapper around the required bits of the api (not a nif or anything else that might crash the vm... http://www.erlang.org/doc/tutorial/erl_interface.html)

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

- https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Deployment_Guide/s1-Using_PTP.html

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


http://zentrope.tumblr.com/post/149688423/erlang-multicast-presencediscovery-notification

