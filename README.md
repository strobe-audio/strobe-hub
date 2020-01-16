# Strobe Audio

http://strobe.audio

## Strobe Hub

This is the umbrella project for the code that comprises the Strobe Audio hub.

Strobe is a multi-room audio system built from scratch in Elixir by
[@magnetised](https://github.com/magnetised").

## Overview

Strobe is comprised of this 'hub' or 'broadcaster' (or 'server'). This acts as
both a store of music and also the means for playing it.

Connecting to the hub are some number of 'receivers'. These are Raspberry Pis
with IQaudIO DACs connected to some kind of hi-fi amplifier and speakers.

In order to play your music Strobe is currently* modelled around the following
core concepts:

- Music is stored in a set of 'libraries'.

  There are currently only two libraries: a disk-based 'your music' library
  (think iTunes) and a set of live BBC radio streams. This should change with
  time.

- Tracks are added from libraries to named 'channels'.

- Receivers are attached to channels.


```
┌────────────────────────────────────────────────────────────────────────────┐
│                                 Strobe Hub                                 │
│                                                                            │
│ ┌─────────────────────────────────┐ ┌─────────────────────────────────┐    │
│ │                                 │ │                                 │    │
│ │                                 │ │                                 │    │
│ │             Library             │ │             Library             │    │
│ │                                 │ │                                 │    │
│ │                                 │ │                                 │    │
│ └─────────────────────────────────┘ └─────────────────────────────────┘    │
│ ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐    │
│ │                     │ │                     │ │                     │    │
│ │                     │ │                     │ │                     │    │
│ │       Channel       │ │       Channel       │ │       Channel       │    │
│ │                     │ │                     │ │                     │    │
│ │                     │ │                     │ │                     │    │
│ └─────────────────────┘ └─────────────────────┘ └─────────────────────┘    │
│            ▲                       ▲                                       │
│            │                       │                                       │
└────────────┼───────────────────────┼───────────────────────────────────────┘
             │                       │
             │                       │
             │                       │
         ┌───┘               ┌───────┴───────────┬───────────────────┐
         │                   │                   │                   │
         │                   │                   │                   │
         │                   │                   │                   │
         │                   │                   │                   │
         │                   │                   │                   │
         │                   │                   │                   │
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│                 │ │                 │ │                 │ │                 │
│                 │ │                 │ │                 │ │                 │
│    Reciever     │ │    Reciever     │ │    Reciever     │ │    Reciever     │
│                 │ │                 │ │                 │ │                 │
│                 │ │                 │ │                 │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘
```

Channels are the core of the strobe system. Strobe is capable of playing
multiple channels at the same time (hence the name). For instance you may want
to listen to your music downstairs so you add your songs to a channel named
"Jane's Music" and attach the "Kitchen" and "Living room" receivers, however
your partner may want to listen to the radio upstairs, so they use the existing
"Radio 6" channel and attach the "Bedroom" and "Bathroom" receivers to it.

Later if your partner goes out and you want to listen to your music throughout
the house you can reattach the "Bedroom" and "Bathroom" receivers to your music
channel.

Part of the purpose of channels is to persist before and after they are in
active use and also provide convenient shortcuts for often used live streams.
For example if you suddenly remember that album you want to listen to at the
weekend, then you can add the album you want to some channel and then, when the
weekend comes, the music you wanted is there waiting for you.

\* 'Currently' because this mode of interaction is still in proof of concept
phase. Though powerful and not overly complex, I'm still deciding if there
isn't something simpler lurking. The only way to decide this is to gather more
experience of using the system from both myself and others.

## Status

Strobe is still in relatively early stages. Although the back-end functions are
fairly solid (music playback is fully functional and extremely reliable) the
user-facing side of things is still in their infancy. This extends from the
installation experience to the UI.

Note that ongoing development is also a form of extreme 'mobile first'. To the
extent that the current UI doesn't work well in desktop browsers. This is just
a temporary glitch while I work out the last details of the library
interaction.

## Roadmap

This is a very high-level overview of the project aims over the short- to
mid-term:

- Complete basic interaction design (including wifi settings and music library
  configuration)
- Skin UI with reasonable & consistent visual design
- Package hub for embedded deployment using Nerves
- Manage music library through e.g. webdav
- Expand library access:
  -  DNLA renderer (to enable playback of audio files from a NAS)
  -  add Shairport receiver (so a single channel can be setup to play music
     from iOS/macOS device)
  - Add more radio options
  - Google Music (using [gmusicapi](https://github.com/simon-weber/gmusicapi))

The longer term aim is to provide some, potentially paid, form of over-the-air
updates for both hub and receiver.

## Contribute

If you'd like to contribute then please, be my guest.

I'm particularly keen on finding a front-end designer to help me transform a
functional but very rough user interface into something beautiful.

## Installation

Generating pre-built images is a WIP.

Strobe requires the following dependencies to run.

### Prerequisites

On a Mac, an up-to-date homebrew installation is the easiest/recommended route
to install the required dependencies.

https://brew.sh/

Be sure to `brew update` before installation to get the latest versions.

### Erlang 19

- Mac: `brew install erlang`
- Ubuntu 18.04+: `sudo apt install erlang`

### Elixir 1.4

Install the latest Elixir using the [installation instructions on the Elixir
website](http://elixir-lang.org/install.html).

### Elm 0.18

Follow the [instructions for your
platform](https://guide.elm-lang.org/install.html) at the [elm-lang
website](http://elm-lang.org/).

This should give you the `elm-package` command.

    cd apps/elvis
    elm-package install

### Yarn

The UI is compiled using Webpack. To install this and its dependencies use
[Yarn](https://yarnpkg.com/en/docs/install).

    cd apps/elvis
    yarn install


### SQLite 3

Strobe is backed by a SQLite database and you'll need the development libraries
to compile the bindings.

- Mac: macOS comes with SQLite 3 pre-installed.
- Ubuntu: `sudo apt install libsqlite3-dev`

### ffmpeg

Strobe uses `ffmpeg` to transcode all audio into 16-bit 44,100 kHz PCM streams:

- Mac: `brew install ffmpeg`
- Ubuntu: `sudo apt install ffmpeg`

### Mediainfo

Currently during music library import Strobe uses the `mediainfo` binary to
extract music metadata.

- Mac: `brew install mediainfo`
- Ubuntu: `sudo apt install mediainfo`

### Bonjour/mDNS

Recievers use various techniques to discover the active hub. One of those
techniques is to register a service using mDNS backed by Bonjour on macOS and
Avahi on linux.

- Mac: No installation necessary -- macOS comes preinstalled with an mDNS framework.
- Ubuntu: `sudo apt install avahi-daemon libavahi-compat-libdnssd-dev`

### Bootstrapping

#### Dependencies

You need to retrieve the Elixir dependencies:

    mix deps.get

#### Databases

Strobe maintains two databases: the hub state and your music library.

Both of these databases require initialization.


From the root of the project directory run

    mix ecto.create -r Otis.State.Repo
    mix ecto.migrate -r Otis.State.Repo

    mix ecto.create -r Peel.Repo
    mix ecto.migrate -r Peel.Repo


### Importing your music

There is currently no UI for adding music to your library. To do this we must
run a command from the terminal which tells [Peel][] to recursively scan a
particular directory for music files and import them into your library.

    mix run --eval 'Peel.scan(["/path/to/music..."])'

This may take some time.

The import will also attempt to provide cover art for any tracks that are
missing it. This uses the [musicbrainz cover art API][] which is rate-limited
to 1 request per second. You can safely `ctrl-c ctrl-c` out of this part though
as the update will proceed in the background next time (and any time) you start
the server.

[Peel]: (https://github.com/strobe-audio/strobe-hub/tree/master/apps/peel)
[musicbrainz cover art API]: (https://wiki.musicbrainz.org/Cover_Art_Archive/API)

## Running

From the root of the project directory run

    mix phoenix.server

all being well this should launch a HTML ui on
[http://localhost:4000](http://localhost:4000)


## License

Stobe Audio Hub
Copyright (C) 2017 Garry Hill

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
