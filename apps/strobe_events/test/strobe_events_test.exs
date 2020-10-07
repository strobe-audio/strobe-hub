defmodule Strobe.EventsTest do
  use ExUnit.Case

  describe "Handler not filtering :__complete__ events" do
    test "Messages get sent" do
      ForwardingHandler.attach()
      Strobe.Events.notify(:something, :else, [:here])
      assert_receive {:something, :else, [:here]}
    end

    test "Completion messages get sent & forwarded" do
      ForwardingHandler.attach()
      Strobe.Events.notify(:something, :else, [:here])
      assert_receive {:something, :else, [:here]}
      assert_receive {:__complete__, {:something, :else, [:here]}, ForwardingHandler}
    end
  end

  describe "Handler filtering :__complete__ events" do
    test "Messages get sent" do
      selector = fn
        {:something, _, _} -> true
        _ -> false
      end

      FilteredForwardingHandler.attach(selector)
      Strobe.Events.notify(:something, :else, [:here])
      Strobe.Events.notify(:otherthing, :else, [:here])
      assert_receive {:something, :else, [:here]}
      refute_receive {:otherthing, :else, [:here]}
    end

    test "Completion messages don't get forwarded" do
      selector = fn _ -> true end
      FilteredForwardingHandler.attach(selector)
      Strobe.Events.notify(:something, :else, [:here])
      assert_receive {:something, :else, [:here]}
      refute_receive {:__complete__, {:something, :else, [:here]}, _}
    end
  end
end
