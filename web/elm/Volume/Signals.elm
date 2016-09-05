module Volume.Signals (..) where


volumeChange : Signal.Mailbox ( String, String, Float )
volumeChange =
  Signal.mailbox ( "", "", 0.0 )
