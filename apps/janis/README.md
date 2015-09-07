Janis
=====

```elixir

{:ok, song} = File.read "/Users/garry/Seafile/Peep/audio/song.raw"

Janis.Player.play song

```

Jack
----

See http://wiki.linuxaudio.org/wiki/raspberrypi

Installing Jack on RPi:

- http://rpi.autostatic.com
- `sudo apt-cache policy jackd2`:

```
jackd2:
  Installed: 1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1
  Candidate: 1.9.8~dfsg.4+20120529git007cdc37-5+rpi2
  Version table:
     1.9.8~dfsg.4+20120529git007cdc37-5+rpi2 0
        500 http://archive.raspberrypi.org/debian/ wheezy/main armhf Packages
     1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1 0
        500 http://rpi.autostatic.com/raspbian/ wheezy/main armhf Packages
     1.9.8~dfsg.4+20120529git007cdc37-5 0
        500 http://mirrordirector.raspbian.org/raspbian/ wheezy/main armhf Packages
```

- `sudo apt-get install libjack-jackd2-0=1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1 jackd2=1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1`


- List audio devices: `aplay -l`
