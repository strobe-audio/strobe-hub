module Receiver.Signals (..) where


attach : Signal.Mailbox ( String, String )
attach =
  Signal.mailbox ( "", "" )
