Otis
====

{:ok, z1} = Otis.Channels.find "f058c281-9186-4585-81f5-b61399c8c729"
{:ok, z2} = Otis.Channels.find "b136576d-0cc2-40a0-a81b-61ef39dd1a92"

{:ok, r1} = Otis.Receivers.receiver "626de8c0-b0ea-5ea4-bb63-48f55fee70fa"
{:ok, r2} = Otis.Receivers.receiver "8437fa0f-0f19-5022-8140-b81b51674680"

Otis.Channel.play_pause z1
Otis.Channel.play_pause z2

# etc
Otis.Channel.add_receiver z2, r2

```elixir

{:ok, channel} = Otis.Channels.start_channel("downstairs", "Downstairs")

{:ok, aine} = Otis.Receiver.start_link("aine", :"aine@192.168.1.89")
{:ok, garry} = Otis.Receiver.start_link("garry", :"garry@192.168.1.64")

Otis.Channel.add_receiver(channel, aine)
Otis.Channel.add_receiver(channel, garry)

{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/bottle_160bpm_4-4time_80beats_stereo_a4kbLz.mp3")
Otis.SourceList.append(ss, source)

Otis.Channel.play_pause(channel)

#############
# Office
#############

{:ok, channel} = Otis.Channels.find "downstairs"
## 5m Silence

{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/5m-silence.mp3")
Otis.SourceList.append(ss, source)
Otis.Channel.play_pause(channel)

## 1 hr silence
{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
Enum.each 1..12, fn(_) ->
  {:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/5m-silence.mp3")
  Otis.SourceList.append(ss, source)
end
Otis.Channel.play_pause(channel)

## 5 hr silence
{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
Enum.each 1..60, fn(_) ->
  {:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/5m-silence.mp3")
  Otis.SourceList.append(ss, source)
end
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/SongMaven-Click-Track-120-BPM.mp3")
Otis.SourceList.append(ss, source)

Otis.Channel.play_pause(channel)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Unknown Artist/Unknown Album/Lady Sovereign - All Eyes On Me (garage).mp3")
Otis.SourceList.append(ss, source)

Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/apex-twin--peek-824545201.m4a")
Otis.SourceList.append(ss, source)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "office"
{:ok, channel} = Otis.Channels.find(Otis.State.Channel.first.id)
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/shubert-piano-quintet.m4a")
Otis.SourceList.append(ss, source)
Otis.Channel.play_pause(channel)


{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/shubert-piano-quintet.m4a")
Otis.SourceList.append(ss, source)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Oliver Jeffers/How to catch a star/01 Untitled.m4a")
Otis.SourceList.append(ss, source)
Otis.Channel.play_pause(channel)

## Albums


{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Music/iTunes/iTunes Media/Music/Richard Dawson/The Magic Bridge")
Otis.SourceList.append(ss, sources)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Music/iTunes/iTunes Media/Music/Richard Dawson/The Glass Trunk")
Otis.SourceList.append(ss, sources)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Music/iTunes/iTunes Media/Music/Richard Dawson/Nothing Important")
Otis.SourceList.append(ss, sources)

Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Seafile/Peep/audio/Tomorrow's Modern Boxes")
Otis.SourceList.append(ss, sources)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Seafile/Peep/audio/Tomorrow's Modern Boxes")
Otis.SourceList.append(ss, sources)
Otis.Channel.play_pause(channel)


Otis.Channel.skip(channel, "585747910cf6af2ba29fecd8b13eeb77")
Otis.Channel.skip(channel, "3c283aeb0c669255fe59359b97a11616")



{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Jackson 5/Jackson 5_ The Ultimate Collection"
Otis.SourceList.append(ss, sources)

Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I"
Otis.SourceList.append(ss, sources)

Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Deerhoof/Milk Man"
Otis.SourceList.append(ss, sources)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Pixies/Doolittle"
Otis.SourceList.append(ss, sources)

{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Westing (By Musket And Sextant)"
Otis.SourceList.append(ss, sources)


# CELLO
{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Compilations/Cello Suites 1, 4 & 5"
Otis.SourceList.append(ss, sources)
Otis.Channel.play_pause(channel)

## Pavement

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/01 Texas Never Whispers.m4a")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/02 Frontwards.m4a")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/03 Lions.m4a")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/04 Shoot The Singer.m4a")
Otis.SourceList.append(ss, source)



## SHORT SAMPLE
{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, channel} = Otis.Channels.find(Otis.State.Channel.first.id)
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/song.mp3")
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.Channel.play_pause(channel)

{:ok, channel} = Otis.Channels.find "office"
{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/song.mp3")
Otis.SourceList.append(ss, source)


{:ok, channel} = Otis.Channels.find "downstairs"
{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/song.mp3")
Otis.SourceList.append(ss, source)

{:ok, channel} = Otis.Channels.find(Otis.State.Channel.first.id)
Otis.Channel.play_pause(channel)

#############

{:ok, channel} = Otis.Channels.find "downstairs"

{:ok, ss} = Otis.Channel.source_list(channel)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/SongMaven-Click-Track-120-BPM.mp3")
Otis.SourceList.append(ss, source)

Otis.Channel.play_pause(channel)


#############
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/10 Somebody To Love.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/17 We Are The Champions.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/03 Killer Queen.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/Snake_Rag.mp3")
Otis.SourceList.append(ss, source)

###############


{:ok, channel} = Otis.Channels.start_channel("office", "Office")

{:ok, mac} = Otis.Receiver.start_link("mac", :"janis@garry-macpro-11")

Otis.Channel.add_receiver(channel, mac)

{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceList.append(ss, source)

Otis.Channel.play_pause(channel)

###############


{:ok, channel} = Otis.Channels.start_channel("office", "Office")

{:ok, mac} = Otis.Receiver.start_link("mac", :"janis@garry-macpro-11")

Otis.Channel.add_receiver(channel, mac)

{:ok, ss} = Otis.Channel.source_list(channel)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceList.append(ss, source)

Otis.Channel.play_pause(channel)

```
