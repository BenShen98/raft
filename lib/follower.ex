
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consenus, v1
# Leyang Shen (ls2617)

defmodule Follower do

# using: s for 'server/state', m for 'message'

def start(s) do

  s=State.restart_election_timer(s)

  if s.config.show_role_switch, do: Monitor.server(s, "switched to #{s.role}")
  next(s)
end # start

def next(s) do

  {s_next, escape} =
    receive do

      {:CLIENT_REQUEST, payload} ->
        {State.forward_client_request(s, payload), false}

      {:ele_timeout, data} ->
        if data=={s.curr_term, s.role} do
          # timeout from current msg
          {State.role(s, :CANDIDATE), true}
        else
          # ignore timeout from previous state
          {s, false}
        end

      {type, data} when type in [:APE_REQUEST, :VOTE_REQUEST]->

        State.check_term_and(s,type,data,
        fn(s) ->
          case type do
            :APE_REQUEST ->
              %{:s=>s} = State.handel_ape_request(s, data)

              s = if data.term==s.curr_term do State.restart_election_timer(s) else s end


              {s, false} # not implemented

            :VOTE_REQUEST ->
              %{:voteGranted=>granted, :s=>s} = State.handel_vote_request(s, data)

              s = if granted do State.restart_election_timer(s) else s end
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
  if escape==true do
    s_next
  else
    next(s_next)
  end
end # next

end # Follower
