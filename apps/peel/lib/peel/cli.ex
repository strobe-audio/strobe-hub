defmodule Peel.Cli do
  def main(args) do
    args |> parse_args |> process
  end

  def process(args) do
    paths = Keyword.get_values(args, :path)
    Peel.scan(paths)
  end

  defp parse_args(args) do
    {options, _, _} =
      OptionParser.parse(args,
        switches: [path: :keep]
      )

    options
  end
end
