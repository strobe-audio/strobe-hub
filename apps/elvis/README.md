# Elvis

Elvis is all show.

It's a phoenix application backed by an Elm-powered UI that links up your
libraries to your channels to your receivers.

When you run the Strobe hub, it's really Elvis that you're launching.

## TODO

### Short

- [ ] Icons for top-level library items ("Albums", "Artists" etc.)

### Medium

- [ ] Delete a channel

### Long

- [ ] Scroll long names (as in iOS)

### Done

- [X] Stop text overflow in to-level player
- [X] Fix display of library breadcrumb
- [X] Folder-level actions (e.g. play an album when viewing it)
- [X] Library search (a new `search` action on the folder)
- [X] Delete individual playlist entries
- [X] Upgrade to Elm 0.17
- [X] Use url for routing (to avoid channel switches). Wait for Elm 0.17
  - current channel
  - playlist/library view
- [X] Use external api (musicbrainz) to improve track metadata (specifically
  cover images)
- [X] Switching library view from long list to short doesn't update the scroll
  position

