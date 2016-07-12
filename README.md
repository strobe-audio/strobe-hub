# HLS

**TODO: Add description**

http://steveseear.org/high-quality-bbc-radio-streams/

e.g. radio 4 streams high/med/low bandwidth;

http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/uk/sbr\_high/ak/bbc\_radio\_fourfm.m3u8
http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/uk/sbr\_med/ak/bbc\_radio\_fourfm.m3u8
http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/uk/sbr\_low/ak/bbc\_radio\_fourfm.m3u8

Streams are MPEG-2 transports, or `mpegtsraw` in avconv/ffmpeg speak.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add hls to your list of dependencies in `mix.exs`:

        def deps do
          [{:hls, "~> 0.0.1"}]
        end

  2. Ensure hls is started before your application:

        def application do
          [applications: [:hls]]
        end
