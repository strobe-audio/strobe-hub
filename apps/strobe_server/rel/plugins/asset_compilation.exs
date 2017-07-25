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
      env: env(),
    ]

    IO.puts "Compiling JS & CSS..."
    System.cmd(Path.join([bin, "webpack"]), [
      "--config",
      "config/webpack.config.js",
      "-p",
    ], opts) |> raise_on_cmd_failure("webpack compile")

    IO.puts "Generating asset digest..."
    System.cmd(mix(), ["phoenix.digest"], opts) |> raise_on_cmd_failure("mix phoenix.digest")
  end

  defp yarn do
    System.find_executable("yarn")
  end
  defp mix do
    System.find_executable("mix")
  end

  defp raise_on_cmd_failure({_, 0}, _cmd), do: nil
  defp raise_on_cmd_failure(result, cmd) do
    raise "#{cmd} returned #{inspect result}"
  end

  defp env do
    [ {"MIX_TARGET", System.get_env("MIX_TARGET")},
    ]
  end
end
