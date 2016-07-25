# HLS

**TODO: Add description**

http://steveseear.org/high-quality-bbc-radio-streams/

e.g. radio 4 streams high/med/low bandwidth;

http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/uk/sbr\_high/ak/bbc\_radio\_fourfm.m3u8
http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/uk/sbr\_med/ak/bbc\_radio\_fourfm.m3u8
http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/uk/sbr\_low/ak/bbc\_radio\_fourfm.m3u8

Streams are MPEG-2 transports, or `mpegtsraw` in avconv/ffmpeg speak.

## Use via the CLI
```
# From some elvis instance
$ iex -S mix
{:ok, c} = Otis.Channels.find "83936d2d-4f50-4dff-80a7-24a672987faa"
radio4 = BBC.radio4
Otis.Channel.append c, radio4
Otis.Channel.sources c
Otis.Channel.play_pause c
```

