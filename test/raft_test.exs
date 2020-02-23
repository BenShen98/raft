defmodule RaftTest do
  use ExUnit.Case
  doctest Raft

  test "get_log" do
    s = %{
      log: [{:a,1}, {:b,2}, {:c,2}, {:d,6}]
    }
    assert State.get_log(s, 0) == {0,0}
    assert State.get_log(s, 3) == {2,3}
    assert State.get_last_log(s) == {6,4}
    assert State.get_prev_log(s, length(s.log)+1) == {6,4}
  end
end
