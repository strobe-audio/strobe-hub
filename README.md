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

UDP
---

- http://zentrope.tumblr.com/post/149688423/erlang-multicast-presencediscovery-notification

server:

    {:ok, socket} = :gen_udp.open 0, ip: {0, 0, 0, 0}, multicast_ttl: 255

    :gen_udp.send socket,  {239,0,0,251}, 6666, <<"hello">>

client:

    {:ok, socket} = :gen_udp.open 6666, [:binary, active: true, ip: {239,0,0,251}, add_membership: {{239,0,0,251}, {0, 0, 0, 0}}, reuseaddr: true]

    receive do; msg -> msg; end


