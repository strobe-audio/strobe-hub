defmodule Plug.WebDAV.LockTest do
  use ExUnit.Case

  alias Plug.WebDAV.Lock

  setup do
    Lock.reset!()
    {:ok, root1: "/my/webdav/root-1", root2: "/my/webdav/root-2"}
  end

  test "creating a lock", cxt do
    {:ok,
     %Lock{
       scope: :exclusive,
       type: :write,
       depth: :infinity,
       id: id1,
       path: "/something",
       timeout: 12_340
     } = lock1} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 12_340)

    {:ok,
     %Lock{
       scope: :exclusive,
       type: :write,
       depth: 0,
       id: id2,
       path: "/something-else",
       timeout: 3_600
     } = lock2} = Lock.acquire_exclusive(cxt.root1, ["something-else"], depth: 0)

    assert id1 != id2
    assert [lock1] == Lock.locks(cxt.root1, ["something"])
    assert [lock2] == Lock.locks(cxt.root1, ["something-else"])
  end

  test "locking root", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, [])
    assert [lock] == Lock.locks(cxt.root1, [])
    assert [lock] == Lock.locks(cxt.root1, ["something"])
  end

  test "locking root with depth: 0", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, [], depth: 0)
    assert [lock] == Lock.locks(cxt.root1, [])
    assert [] == Lock.locks(cxt.root1, ["something"])
  end

  test "creating a duplicate lock", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 12_340)

    {:error, :duplicate, [^lock]} =
      Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 12_340)

    {:error, :duplicate, [^lock]} =
      Lock.acquire_exclusive(cxt.root1, ["something", "below", "this"], timeout: 12_340)
  end

  test "creating a lock in different root", cxt do
    {:ok, _id1} = Lock.acquire_exclusive(cxt.root1, ["something"])
    assert [] == Lock.locks(cxt.root2, ["something"])
  end

  test "propagation to a sub-resource", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 12_340)
    assert [lock] == Lock.locks(cxt.root1, ["something", "below", "the", "lock.mp3"])
  end

  test "propagation to a sub-resource with depth: 0", cxt do
    {:ok, _lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 12_340, depth: 0)
    assert [] == Lock.locks(cxt.root1, ["something", "below", "the", "lock.mp3"])
  end

  test "lock expiry", cxt do
    {:ok, _lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 5)
    assert [] == Lock.locks(cxt.root1, ["something"], Lock.now() + 100)
  end

  test "listing locks", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 5)
    assert [lock] == Lock.all()
  end

  test "releasing locks with valid token", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 5)
    assert [lock] == Lock.all()
    other_token = Lock.gen_id()
    :ok = Lock.release(cxt.root1, ["something"], [lock.id, other_token])
    assert [] == Lock.all()
  end

  test "releasing locks with invalid token", cxt do
    {:ok, lock} = Lock.acquire_exclusive(cxt.root1, ["something"], timeout: 5)
    assert [lock] == Lock.all()
    other_token = Lock.gen_id()
    {:error, :invalid_path_token} = Lock.release(cxt.root1, ["something"], [other_token])
    assert [lock] == Lock.all()
  end
end
