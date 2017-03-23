# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#

platform = case to_string(:erlang.system_info(:system_architecture)) do
  <<"x86_64-apple-darwin", _version::binary>> ->
    "x86_64-apple-darwin"
  other ->
    other
end

config :porcelain, :driver, Porcelain.Driver.Goon
config :porcelain, :goon_driver_path, Path.expand("#{__DIR__}/../bin/goon-#{platform}")

import_config "#{Mix.env}.exs"
