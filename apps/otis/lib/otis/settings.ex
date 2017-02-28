defmodule Otis.Settings do
  @application :otis
  @ns_order [:wifi]
  @default_values %{
    wifi: %{ psk: "", ssid: "" },
  }
  @schema %{
    wifi: [
      ssid: %{ inputType: :text },
      psk: %{ inputType: :password },
    ]
  }
  @titles %{
    wifi: "Wifi settings",
  }

  def application, do: @application

  def current do
    {:ok, values} = Otis.State.Setting.application(@application)
    settings =
      Enum.map(@ns_order, fn(ns) ->
        values = Map.merge(@default_values[ns], Map.get(values, ns, %{}))
        fields = Enum.map(@schema[ns], fn({key, type}) ->
          Map.merge(type, %{application: @application, namespace: ns, name: to_string(key), value: values[key]})
        end)
        %{application: @application, namespace: ns, title: @titles[ns], fields: fields}
      end)
    {:ok, settings}
  end

  def save_fields([]) do
    :ok
  end
  def save_fields([%{"namespace" => namespace, "name" => name, "value" => value} = _field | fields]) do
    Otis.State.Setting.put(@application, namespace, name, value)
    save_fields(fields)
  end
end
