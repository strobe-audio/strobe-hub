IO.inspect [:HERE]
defmodule Strobe.Server.Release.AssetCompilation do
  use Mix.Releases.Plugin

  def before_assembly(release, opts) do
    IO.inspect [:before_assembly, release, opts]
    release
  end
  def after_assembly(release, opts) do
    IO.inspect [:after_assembly, release, opts]
    release
  end
  def before_package(release, opts) do
    IO.inspect [:before_package, release, opts]
    release
  end
  def after_package(release, opts) do
    IO.inspect [:after_package, release, opts]
    release
  end
end
