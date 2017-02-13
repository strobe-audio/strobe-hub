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

## Full text search

Enable full text search using sqlite fts4 extension:

```
create virtual table artists_search_index using fts4(content='', 'normalized_name')

insert into artists_search_index(docid, normalized_name) select rowid, normalized_name from artists;

select * from artists where rowid in (
  select docid from artists_search_index where artists_search_index match 'david'
);
```

This is ok as far as it goes but the results of this come in a basically random
order.

To get the results ranked by relevance in fts3/4 you need to supply a
user-defined `rank` function.

See: http://www.sqlite.org/fts3.html#section_6_2_1

Alternatively `fts5` provides a built-in `rank` function, but enabling the fts5
extension is a thing.
