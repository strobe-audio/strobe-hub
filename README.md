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
- http://swannodette.github.io/mori/

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


