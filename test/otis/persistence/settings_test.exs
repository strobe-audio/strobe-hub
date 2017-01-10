defmodule Otis.Persistence.SettingsTest do
  use   ExUnit.Case

  alias Otis.State.Setting

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    :ok
  end

  test "it writes values JSON encoded" do
    value = %{fish: "fry", dog: "tooth"}
    %Setting{} = Setting.put :test, :value, value
    assert {:ok, %{"fish" => "fry", "dog" => "tooth"}} == Setting.get :test, :value
  end

  test "it can write bare string values" do
    Setting.put :test, :value, "fish"
    assert {:ok, "fish"} == Setting.get :test, :value
  end

  test "it can overwrite values" do
    Setting.put :test, :value, "fish"
    Setting.put :test, :value, "door"
    assert {:ok, "door"} == Setting.get :test, :value
  end

  test "it returns all values from a namespace as a map" do
    values = [key1: %{fish: "fry1", dog: "tooth1"}, key2: %{fish: "fry1", dog: "tooth1"}]
    Enum.each values, fn({k, v}) ->
      Setting.put :test, k, v
    end
    assert {:ok, %{
      key1: %{"fish" => "fry1", "dog" => "tooth1"},
      key2: %{"fish" => "fry1", "dog" => "tooth1"}
    }} == Setting.namespace(:test)
  end

  test "it returns :error when no value is found for a key" do
    assert :error == Setting.get(:test, :value)
  end

  test "it returns :error when no values are found in a namespace" do
    assert :error == Setting.namespace(:test)
  end
end
