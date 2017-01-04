
defmodule Peel.String do
  def normalize(string) do
    string
    |> replace_ampersands
    |> String.normalize(:nfd)
    |> String.codepoints
    |> Enum.map(&convert_punctuation/1)
    |> Enum.reject(&is_combining_mark?/1)
    |> Enum.join
    |> String.strip
    |> normalize_whitespace
    |> String.downcase
  end

  @doc """
  Normalize a performer name, stripping leading 'the's
  """
  def normalize_performer(string) do
    string
    |> normalize
    |> strip_leading_the
  end

  # http://www.regular-expressions.info/unicode.html

  # \p{M} -> a character intended to be combined with another character (e.g.
  #          accents, umlauts, enclosing boxes, etc.)
  # \p{C} -> invisible control characters and unused code points
  @mark_regex ~r/(\p{M}|\p{C})/u

  # \p{P} -> any kind of punctuation character.
  # \p{S} -> math symbols, currency signs, dingbats, box-drawing characters, etc.
  @punctuation_regex ~r/(\p{P}|\p{S})/u

  # \p{Z} -> any kind of whitespace or invisible separator.
  @whitespace_regex ~r/\p{Z}+/u

  @ampersand_regex ~r/&(?:amp)?;?/u

  @the_regex ~r/^[Tt]he +/u

  @doc "Replace punctuation characters with spaces."
  def convert_punctuation(char) do
    case Regex.match?(@punctuation_regex, char) do
      true -> " "
      false -> char
    end
  end

  @doc "Remove any combining marks (exposed by String.normalize(:nfd))"
  def is_combining_mark?(char) do
    Regex.match?(@mark_regex, char)
  end

  @doc "Replace runs of whitespace with single spaces"
  def normalize_whitespace(string) do
    Regex.replace(@whitespace_regex, string, " ")
  end

  @doc """
  Replace '&' characters with the word 'and'. Handles HTML encoded values because
  they crop up every bloody where.
  """
  def replace_ampersands(string) do
    Regex.replace(@ampersand_regex, string, "and")
  end

  @doc """
  Remove leading 'the' so that performer names can be sorted ignoring them.
  """
  def strip_leading_the(string) do
    Regex.replace(@the_regex, string, "")
  end
end
