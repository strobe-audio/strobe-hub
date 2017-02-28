defmodule Otis.Persistence.SettingsTest do
  use   ExUnit.Case

  alias Otis.State.Setting

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    :ok
  end

  test "it writes values JSON encoded" do
    value = %{fish: "fry", dog: "tooth"}
    %Setting{} = Setting.put :app, :test, :value, value
    assert {:ok, %{"fish" => "fry", "dog" => "tooth"}} == Setting.get :app, :test, :value
  end

  test "it can write bare string values" do
    Setting.put :app, :test, :value, "fish"
    assert {:ok, "fish"} == Setting.get :app, :test, :value
  end

  test "it can overwrite values" do
    Setting.put :app, :test, :value, "fish"
    Setting.put :app, :test, :value, "door"
    assert {:ok, "door"} == Setting.get :app, :test, :value
  end

  test "it returns all values from a namespace as a map" do
    values = [key1: %{fish: "fry1", dog: "tooth1"}, key2: %{fish: "fry1", dog: "tooth1"}]
    Enum.each values, fn({k, v}) ->
      Setting.put :app, :test, k, v
    end
    assert {:ok, %{
      key1: %{"fish" => "fry1", "dog" => "tooth1"},
      key2: %{"fish" => "fry1", "dog" => "tooth1"}
    }} == Setting.namespace(:app, :test)
  end

  test "it returns :error when no value is found for a key" do
    assert :error == Setting.get(:app, :test, :value)
  end

  test "it returns :error when no values are found in a namespace" do
    assert :error == Setting.namespace(:app, :test)
  end

  test "it returns all values for an application as a map" do
    ns_a = [akey1: %{fish: "fry1", dog: "tooth1"}, akey2: %{fish: "fry1", dog: "tooth1"}]
    ns_b = [bkey1: %{carrot: "orange", apple: "green"}, bkey2: %{beetroot: "purple", potato: "white"}]
    Enum.each ns_a, fn({k, v}) ->
      Setting.put :app, :ns_a, k, v
    end
    Enum.each ns_b, fn({k, v}) ->
      Setting.put :app, :ns_b, k, v
    end
    assert {:ok, %{
      ns_a: %{
        akey1: %{"fish" => "fry1", "dog" => "tooth1" },
        akey2: %{"fish" => "fry1", "dog" => "tooth1"}
      },
      ns_b: %{
        bkey1: %{"carrot" => "orange", "apple" => "green"},
        bkey2: %{"beetroot" => "purple", "potato" => "white"}
      }
    }} == Setting.application(:app)
  end
end
