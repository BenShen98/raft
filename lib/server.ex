
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consenus, v1

defmodule Server do

# using: s for 'server/state', m for 'message'

def start(config, server_id, databaseP) do
  receive do
  { :BIND, servers } ->
    s = State.initialise(config, server_id, servers, databaseP)
    Server.next(s)
  end # receive


end # start

def next(s) do

  case s.role do
    :FOLLOWER ->
      Follower.start(s)

    :CANDIDATE ->
      Candidate.start(s)

    :LEADER ->
      Leader.start(s)

    unknown ->
      Monitor.halt(s, "reach unknown #{unknown} role")

  end
  |> State.cancel_election_timer()
  |> make_will([])
  |> next()

end # next

defp make_will(s, wills) do
  {state, wills} = receive do

    {type, data}=msg when type in [:VOTE_REQUEST, :APE_REQUEST,] ->
      if data.term >= s.curr_term do
        Monitor.server(s,10, "give will: #{inspect msg}")
        {:more, wills ++ [msg]}
      else
        Monitor.server(s,0, "flushing (old term): #{inspect msg}")
        {:more, wills}
      end

    {:disaster, disaster}=msg ->
      {:more, wills ++ [msg]}

    others ->
      Monitor.server(s,0, "flushing: #{inspect others}")
      {:more, wills}

    after 0 ->
      {:done,wills}
  end

  case state do
    :more -> make_will(s, wills)
    :done ->
      for will <- wills do
        send self(), will
      end
      s
  end
end

end # Server
