
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

      {:CLIENT_REQUEST, payload} ->
        # IO.puts("#{inspect payload}")
        s = handel_request(s, payload)
        {s, false}

      {:send_ape, id} ->
        Process.send_after self(), {:send_ape, id}, s.config.append_entries_timeout
        {ape(s, id), false}

      {type, data} when type in [:APE_REQUEST, :VOTE_REQUEST, :APE_REPLY]->
        State.check_term_and(s,type,data,
        fn(s) ->
          case type do
            :APE_REQUEST ->
              %{:s => s, :success => success} = State.handel_ape_request(s, data)
              if success do
                Monitor.server(s,30, "LEADER SHOULD NOT RECEIVE AND RETURN SUCCESS FOR APE_REQUEST")
              else
                Monitor.server(s,20, "LEADER SHOULD NOT RECEIVE APE_REQUEST (success=false)")
              end
              {s, false}

            :APE_REPLY ->
              # BUG/TODO: currently only allow one entries at a time
              # Assumption: client term should equal to curr_term (handeled before)
              Monitor.assert s, data.term == s.curr_term

              if data.success do
                prev_next_index = elem(s.next_index, data.id)
                new_next_index = prev_next_index+data.length
                new_match_index = new_next_index-1

                s=update_leader_index(s)
                |> State.next_index(data.id, new_next_index)
                |> State.match_index(data.id, new_match_index)
                |> update_commit_index
                |> State.apply_commited_log

                {s, false}

              else
                # decrement nextIndex
                {State.dec_next_index(s, data.id)
                |> ape(data.id), false} # async retry
              end

            :VOTE_REQUEST ->
              %{:s=>s} = State.handel_vote_request(s, data)

              {s, false}
          end

        end)

      {:disaster, d} ->
        Disaster.handel(s, d)

      {:sinspect} ->
        Monitor.sinspect(s)
        {s, false}

    end

  # state update
  if escape do
    s_next
  else
    next(s_next)
  end
end # next

defp ape(s, id) do
  next_index = elem(s.next_index, id)
  {term, index} = State.get_prev_log(s, next_index)

  # start by send one entries at a time
  entries = if length(s.log) >= next_index do
    [Enum.at(s.log, next_index-1) |> elem(0)]
  else
    # client has its entries in sync, send heartbeat
    []
  end


  request=%{
    term: s.curr_term,
    leaderId: s.id,
    prevLogIndex: index,
    prevLogTerm: term,
    entries: entries,
    leaderCommit: s.commit_index
  }

  send Enum.at(s.servers, id), {:APE_REQUEST, request}

  s
end

defp update_leader_index(s) do
  State.next_index(s, s.id, length(s.log)+1)
  |> State.match_index(s.id, length(s.log))
end

defp update_commit_index(s) do
  majority_commited_index = Enum.sort(Tuple.to_list(s.match_index), :desc) |> Enum.at(s.majority-1)

  if State.get_log(s, majority_commited_index) |> elem(0) == s.curr_term do

    # check errors
    if s.commit_index>majority_commited_index do
      Monitor.halt(s, "commit_index should only go forward")
    end

    # tell client it is commited #BUG: check start index?
    for log <- Enum.slice(s.log, s.commit_index, majority_commited_index-s.commit_index) do
      payload = elem(log, 0)
      Monitor.server(s, 10, "send client confirmation #{inspect payload.uid}")
      send payload.clientP, {:CLIENT_REPLY, %{:leaderP=>self(), :uid=>payload.uid}}
    end

    # update commit index
    State.commit_index(s, majority_commited_index)
  else
    s
  end
end

defp handel_request(s, payload) do # for leader

  if Enum.find(s.log, fn x -> elem(x,0).uid == payload.uid end) == nil do
    # append new request
    Monitor.notify(s, { :CLIENT_REQUEST, s.id })
    Monitor.server(s, 0, "append uid #{inspect payload.uid}")
    Map.put(s, :log, s.log ++ [{payload, s.curr_term}])
  else
    # reply exisiting request
    # with new address
    Monitor.server(s, 0, "reply existing uid #{inspect payload.uid}")
    send payload.clientP, {:CLIENT_REPLY, %{:leaderP=>self(), :uid=>payload.uid}}
    s
  end
end


end # Leader
