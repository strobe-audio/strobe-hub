
defmodule Peel.String do
  def normalize(string) do
    string
    |> replace_ampersands
    |> String.normalize(:nfd)
    |> String.codepoints
    |> Enum.reject(&search_version_strip?/1)
    |> Enum.join
    |> String.strip
    |> normalize_whitespace
    |> String.downcase
  end

  # http://www.regular-expressions.info/unicode.html
  @mark_regex ~r/(\p{M}|\p{P}|\p{S}|\p{C})/u
  @whitespace_regex ~r/\p{Z}+/u
  @ampersand_regex ~r/&/u

  def search_version_strip?(char) do
    Regex.match?(@mark_regex, char)
  end

  def normalize_whitespace(string) do
    Regex.replace(@whitespace_regex, string, " ")
  end

  def replace_ampersands(string) do
    Regex.replace(@ampersand_regex, string, "and")
  end
end
