defmodule Otis.SettingsTest do
  use ExUnit.Case

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    :ok
  end

  test "can retrieve application settings with schema" do
    app = Otis.Settings.application
    Otis.State.Setting.put app, :wifi, :psk, "mysharedkey"
    Otis.State.Setting.put app, :wifi, :ssid, "mynetwork"

    {:ok, settings} = Otis.Settings.current
    assert settings == [
      %{
        application: :otis,
        namespace: :wifi,
        title: "Wifi settings",
        fields: [
          %{application: :otis, namespace: :wifi, name: "ssid", value: "mynetwork", inputType: :text, title: "Network"},
          %{application: :otis, namespace: :wifi, name: "psk", value: "mysharedkey", inputType: :password, title: "Password"},
        ]
      }
    ]
  end

  test "gives sane default values" do
    {:ok, settings} = Otis.Settings.current
    assert settings == [
      %{
        application: :otis,
        namespace: :wifi,
        title: "Wifi settings",
        fields: [
          %{application: :otis, namespace: :wifi, name: "ssid", value: "", inputType: :text, title: "Network"},
          %{application: :otis, namespace: :wifi, name: "psk", value: "", inputType: :password, title: "Password"},
        ]
      }
    ]
  end

  test "can save settings received from UI" do
    fields = [
      %{"application" => "otis", "inputType" => "text", "name" => "ssid", "namespace" => "wifi", "value" => "mynewnetwork"},
      %{"application" => "otis", "inputType" => "password", "name" => "psk", "namespace" => "wifi", "value" => "mynewpassword"}
    ]
    :ok = Otis.Settings.save_fields fields
    app = Otis.Settings.application
    {:ok, "mynewnetwork"} = Otis.State.Setting.get app, :wifi, :ssid
    {:ok, "mynewpassword"} = Otis.State.Setting.get app, :wifi, :psk
  end
end
