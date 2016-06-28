# Peel

    mix run --eval 'Peel.scan(["/path/to/music..."])'


## Cover art

Use musicbrainz to retreive cover art and artist pics?

- https://musicbrainz.org/doc/Cover\_Art\_Archive/API
- https://musicbrainz.org/doc/Development/XML\_Web\_Service/Version\_2
- http://stackoverflow.com/questions/24045166/querying-musicbrainz-search-api-via-php-script

or some other service?

- https://musicmachinery.com/music-apis/

## Schema

```
    ┏━━━━━━━━━━━━━━━┓          ┌ ─ ─ ─ ─ ─ ─ ─ ┐
    ┃               ┃         ╱
    ┃    artists    ┃┼─────────│ album_artists │
    ┃               ┃         ╲
    ┗━━━━━━━━━━━━━━━┛          └ ─ ─ ─ ─ ─ ─ ─ ┘
            ┼                         ╲│╱
            │                          │
            │                          │
           ╱│╲                         ┼
    ┏━━━━━━━━━━━━━━━┓          ┏━━━━━━━━━━━━━━━┓
    ┃               ┃╲         ┃               ┃
    ┃    tracks     ┃─────────┼┃    albums     ┃
    ┃               ┃╱         ┃               ┃
    ┗━━━━━━━━━━━━━━━┛          ┗━━━━━━━━━━━━━━━┛
            ┼
            │
            │
           ╱│╲
    ┌ ─ ─ ─ ─ ─ ─ ─ ┐

    │ track_genres  │

    └ ─ ─ ─ ─ ─ ─ ─ ┘
           ╲│╱
            │
            │
            ┼
    ┏━━━━━━━━━━━━━━━┓
    ┃               ┃
    ┃    genres     ┃
    ┃               ┃
    ┗━━━━━━━━━━━━━━━┛

```
