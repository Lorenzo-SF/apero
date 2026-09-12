defmodule Apero.File.IO.AtomicFsyncTest do
  use ExUnit.Case, async: false

  alias Apero.File.IO

  @tag :tmp_dir
  test "atomic_write/3 with fsync: true writes content to disk" do
    path = Path.join(System.tmp_dir!(), "apero_fsync_#{System.unique_integer([:positive])}.txt")
    :ok = IO.atomic_write(path, "fsync content", fsync: true)
    assert File.read!(path) == "fsync content"
    File.rm!(path)
  end

  test "atomic_write/3 with fsync: false (default) works" do
    path = Path.join(System.tmp_dir!(), "apero_nofsync_#{System.unique_integer([:positive])}.txt")
    :ok = IO.atomic_write(path, "no fsync")
    assert File.read!(path) == "no fsync"
    File.rm!(path)
  end

  test "atomic_write/3 still creates parent dirs" do
    base = Path.join(System.tmp_dir!(), "apero_fsync_parent_#{System.unique_integer([:positive])}")
    path = Path.join([base, "sub", "file.txt"])
    :ok = IO.atomic_write(path, "deep", fsync: true)
    assert File.read!(path) == "deep"
    File.rm_rf!(base)
  end

  test "atomic_write/3 fsync: true on non-existent path returns ok" do
    # The fsync step is on the tmp file, which always exists at that
    # point (File.write returned :ok).  So this should succeed.
    path = Path.join(System.tmp_dir!(), "apero_fsync_new_#{System.unique_integer([:positive])}.txt")
    :ok = IO.atomic_write(path, "new file with fsync", fsync: true)
    assert File.read!(path) == "new file with fsync"
    File.rm!(path)
  end
end
