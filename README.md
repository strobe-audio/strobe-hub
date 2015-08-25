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

Bugs
----

- [ ] adding sources to a source stream after all sources have played won't start again
