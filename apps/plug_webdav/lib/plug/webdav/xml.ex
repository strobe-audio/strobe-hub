defmodule Plug.WebDav.Xml do
  def encode(string) do
    string
    |> String.graphemes
    |> Enum.map(&encode_grapheme/1)
    |> Enum.join
  end

  def encode_grapheme("&"), do: "&amp;"
  def encode_grapheme(g), do: g
end
