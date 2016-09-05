module Library.Signals (requests) where


requests : Signal.Mailbox ( String, String )
requests =
  Signal.mailbox ( "", "" )
