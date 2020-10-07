defmodule ExternalProcess do
  @moduledoc """
  Provides a wrapper around Porcelain that takes care of providing the
  required Goon binaries
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(ExternalProcess.Driver, [], restart: :transient)
    ]

    opts = [strategy: :one_for_one, name: ExternalProcess.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def goon_platform do
    case to_string(:erlang.system_info(:system_architecture)) |> String.split("-") do
      # x86_64-apple-darwin-gnu
      ["x86_64", _apple, <<"darwin", _version::binary>>] ->
        "x86_64-apple-darwin"

      # x86_64-unknown-linux-gnu
      ["x86_64", _, "linux", _] ->
        "x86_64-linux-gnu"

      # arm-buildroot-linux-gnueabihf
      ["arm", _, "linux", format] ->
        "arm-linux-#{format}"
    end
  end

  def goon_driver_path do
    [:code.priv_dir(:external_process), "goon-#{goon_platform()}"] |> Path.join() |> Path.expand()
  end

  def spawn(prog, args, options \\ []) do
    Porcelain.reinit(Porcelain.Driver.Goon)
    Porcelain.spawn(prog, args, options)
  end

  def stop(process) do
    Porcelain.Process.stop(process)
  end

  def signal(process, signal) do
    Porcelain.Process.signal(process, signal)
  end

  def await(process, timeout \\ :infinity) do
    Porcelain.Process.await(process, timeout)
  end
end
