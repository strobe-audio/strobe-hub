module Channels.Signals (..) where


addChannel : Signal.Mailbox String
addChannel =
  Signal.mailbox ""

