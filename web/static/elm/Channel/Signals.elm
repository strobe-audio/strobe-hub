module Channel.Signals (..) where


playPause : Signal.Mailbox ( String, Bool )
playPause =
  Signal.mailbox ( "", False )
