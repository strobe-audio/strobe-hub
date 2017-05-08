defmodule Strobe.Server.Release.AssetCompilation do
  use Mix.Releases.Plugin

  def before_assembly(release, _opts) do
    cwd = System.cwd()
    [__DIR__, "../../../elvis"] |> Path.join() |> Path.expand() |> File.cd()
    compile_assets()
    # Go back to where we were
    cwd |> File.cd()
    release
  end

  def after_assembly(release, _opts) do
    release
  end

  def before_package(release, _opts) do
    release
  end

  def after_package(release, _opts) do
    release
  end

  defp compile_assets do
    bin = case System.cmd(yarn(), ["bin"]) do
      {path, 0} ->
        path
      {_, _} ->
        :enoent
    end |> String.strip()

    opts = [
      stderr_to_stdout: true,
      into: IO.stream(:stdio, :line),
    ]

    IO.puts "Compiling JS & CSS..."
    System.cmd(Path.join([bin, "webpack"]), [
      "--config",
      "config/webpack.config.js",
      "-p",
    ], opts)

    IO.puts "Generating asset digest..."
    System.cmd(mix(), ["phoenix.digest"], opts)
  end

  defp yarn do
    System.find_executable("yarn")
  end
  defp mix do
    System.find_executable("mix")
  end
end
