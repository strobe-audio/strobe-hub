# Elvis

To start your Phoenix app:

  1. Install dependencies with `mix deps.get`
  2. Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  3. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

# TODO

## Short

- [ ] Icons for top-level library items ("Albums", "Artists" etc.)
- [ ] Fix display of library breadcrumb

## Medium

- [ ] Folder-level actions (e.g. play an album when viewing it)
- [ ] Library search (a new `search` action on the folder)
- [ ] Delete individual playlist entries
- [ ] Upgrade to Elm 0.17
- [ ] Use url for routing (to avoid channel switches). Wait for Elm 0.17
  - current channel
  - playlist/library view

- [ ] Delete a channel

## Long

- [ ] Use external api (musicbrainz) to improve track metadata (specifically
  cover images)
- [ ] Scroll long names (as in iOS)

# Bugs

- [ ] Switching library view from long list to short doesn't update the scroll
  position

# Done

- [X] Stop text overflow in to-level player
