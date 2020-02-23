
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consenus, v1
# Leyang Shen (ls2617)

defmodule Candidate do

# using: s for 'server/state', m for 'message'

def start(s) do

  s = s
    # start election
    |> State.inc_term()
    |> State.voted_for(nil)
    |> State.votes(0)

    |> State.restart_election_timer()

  # request for vote
  {lastLogTerm, lastLogIndex} = State.get_prev_log(s)
  for server <- s.servers do
    send server, {:VOTE_REQUEST, %{
      :term => s.curr_term,
      :candidateId => s.id,
      :lastLogIndex => lastLogIndex,
      :lastLogTerm => lastLogTerm
    }}
  end

  # NOTE: dont vote for self yet, broadcast include myself, accept it then
  # VOTE_REQUEST can only send once in each term,
  # to prevent vote being counted twice

  Monitor.server(s,10, "switched to #{s.role}")
  next(s)
end # start

def next(s) do

  {s_next, escape} =
    receive do

      {:ele_timeout, data} ->
        if data=={s.curr_term, s.role} do
          # timeout from current msg
          {State.role(s, :CANDIDATE), true}
        else
          # ignore timeout from previous state
          {s, false}
        end

      {type, data} when type in [:APE_REQUEST, :VOTE_REQUEST, :VOTE_REPLY]->
        State.check_term_and(s,type,data,
        fn(s) ->
          case type do

            :APE_REQUEST ->
              # data.term>s.curr_term handled by check_term_and
              if data.term==s.curr_term do
                send self(), {type, data} # make it a will, to be handled by next state
                {State.role(s, :FOLLOWER), true}

              else
                %{:s=>s} = State.handle_ape_request(s, data)

                {s, false}
              end

            # NOTE: here it will vote for itself
            :VOTE_REQUEST ->
              %{:s=>s}=State.handle_vote_request(s, data)
              {s, false}

            :VOTE_REPLY ->
              s=if data.voteGranted do State.inc_vote(s) else s end

              if State.is_majority(s) do
                {State.role(s, :LEADER), true}
              else
                {s, false}
              end

          end

        end)

      {:disaster, d} ->
        Disaster.handle(s, d)

    end

  # state update
  if escape do
    s_next
  else
    next(s_next)
  end
end # next

end # Candidate
