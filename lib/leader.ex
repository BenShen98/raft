
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consenus, v1
# Leyang Shen (ls2617)

defmodule Leader do

# using: s for 'server/state', m for 'message'

def start(s) do
  s=Map.put(s, :next_index, Tuple.duplicate(length(s.log)+1, s.config.n_servers))
  |> Map.put(:match_index, Tuple.duplicate(0, s.config.n_servers))

  # NOTE: inital msg is not empty
  for id <- 0 .. s.config.n_servers-1 do
    if id != s.id do send self(), {:send_ape, id} end
  end

  Monitor.server(s,10, "switched to #{s.role}")
  send s.config.raftP, {:leader_start, s.id}
  next(s)
end # start

def next(s) do

  {s_next, escape} =
    receive do
      # {:APE_REQUEST, data} ->
      #   Monitor.server(s, "APE_REQUEST not implemented")
      #   s

      {:send_ape, id} ->
        Process.send_after self(), {:send_ape, id}, s.config.append_entries_timeout
        {ape(s, id), false}

      {type, data} when type in [:APE_REQUEST, :VOTE_REQUEST, :APE_REPLY]->
        State.check_term_and(s,type,data,
        fn(s) ->
          case type do

            :VOTE_REQUEST ->
              %{:s=>s} = State.handel_ape_request(s, data)

              {s, false}
          end

        end)

      {:disaster, d} ->
        Disaster.handel(s, d)

    end

  # state update
  if escape do
    s_next
  else
    next(s_next)
  end
end # next

defp ape(s, id) do
  {term, index} = State.get_prev_log(s)

  request=%{
    term: s.curr_term,
    leaderId: s.id,
    preLogIndex: index, # TODO: incorrect, should depends on nextindex
    perLogTerm: term,
    entries: [],
    leaderCommit: s.commit_index
  }

  send Enum.at(s.servers, id), {:APE_REQUEST, request}

  s
end

end # Leader
