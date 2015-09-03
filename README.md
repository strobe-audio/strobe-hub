Peep
====

Synchronised Player
-------------------

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

