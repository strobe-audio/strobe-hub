module Channel.Signals (..) where

import ID


playPause : Signal.Mailbox ( String, Bool )
playPause =
  Signal.mailbox ( "", False )


rename : Signal.Mailbox ( ID.Channel, String )
rename =
  Signal.mailbox ( "", "" )
