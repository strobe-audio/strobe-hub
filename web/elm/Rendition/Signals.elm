module Rendition.Signals (..) where


skip : Signal.Mailbox ( String, String )
skip =
  Signal.mailbox ( "", "" )
