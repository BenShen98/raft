
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

defmodule State do

# *** short-names: s for 'server', m for 'message'

def initialise(config, server_id, servers, databaseP) do
  %{
    config:       config,     # system configuration parameters (from DAC)
    selfP:        self(),     # server's process id
    id:	          server_id,  # server's id (simple int)
    servers:      servers,    # list of process id's of servers
    databaseP:    databaseP,  # process id of local database
    majority:     div(length(servers)+1, 2),
    votes:        0,          # count of votes incl. self

    # timerrefs
    election_timer: nil,

    # -- various process id's - omitted

    # -- raft persistent data
    # -- update on stable storage before replying to requests
    curr_term:	  0,
    voted_for:	  nil, # only cleared when enter candidate state (due to inc_term)
    log:          [], # stores {cmd, term} pair

    # -- raft non-persistent data
    role:	  :FOLLOWER, # LEADER,FOLLOWER,CANDIDATE
    commit_index: 0, # index of last commited log
    last_applied: 0, # index of log excuted to db
    next_index:   nil,
    match_index:  nil,

    # add additional state variables of interest
  }
end # initialise

# timer functions
def cancel_election_timer(s) do
  if s.election_timer != nil do
    Process.cancel_timer(s.election_timer)
    Map.put(s, :election_timer, nil)
  else
    s
  end
end

def restart_election_timer(s) do
  if s.election_timer != nil do
    Process.cancel_timer(s.election_timer)
  end

  Map.put(s, :election_timer, Process.send_after(
    self(), {:ele_timeout, {s.curr_term, s.role}}, rand_election_timeout(s)
  ))

end

def force_election_timeout(s) do
  # cancel old timer
  s=cancel_election_timer(s)

  # force timeout
  send self(), {:ele_timeout, {s.curr_term, s.role}}

  # resume timeout
  restart_election_timer(s)

end


# getters
def rand_election_timeout(s), do: Kernel.trunc s.config.election_timeout*(1+:rand.uniform())

def get_last_log(s) do
  # NOTE: new_log_index = length(s.log) + 1
  get_prev_log(s, length(s.log)+1 )
end

def get_prev_log(s, new_log_index) do
  # returns {term, log_index}

  prev_log_index = new_log_index - 1
  #prev_index = prev_log_index - 1 = new_log_index - 2

  cond do
    prev_log_index < 0 ->
      Monitor.halt(s, "invalid log index")
    prev_log_index == 0 ->
      {0, 0} #base case for first new log
    true ->
      {Enum.at(s.log, prev_log_index-1) |> elem(1), prev_log_index}
  end
end

# tester
def is_majority(s), do: s.votes >= s.majority

# setters
def votes(s, v),          do: Map.put(s, :votes, v)

# setters for raft state
def role(s, v),           do: Map.put(s, :role, v)
def curr_term(s, v),      do: Map.put(s, :curr_term, v)
def voted_for(s, v),      do: Map.put(s, :voted_for, v)
def commit_index(s, v),   do: Map.put(s, :commit_index, v)
def last_applied(s, v),   do: Map.put(s, :last_applied, v)
def next_index(s, v),     do: Map.put(s, :next_index, v)      # sets new next_index map
def next_index(s, i, v),  do: Map.put(s, :next_index,
                                  Map.put(s.next_index, i, v))
def match_index(s, v),    do: Map.put(s, :match_index, v)     # sets new  match_index map
def match_index(s, i, v), do: Map.put(s, :match_index,
                                  Map.put(s.match_index, i, v))

# add additional setters
def inc_term(s), do: Map.put(s, :curr_term, s.curr_term+1)
def inc_vote(s), do: Map.put(s, :votes, s.votes+1)

# helper function

# common guard function
def check_term_and(s,type,data, func) do
  if data.term > s.curr_term do
    Monitor.server(s,10, "Higher term found #{ inspect {type,data}}")
    send self(), {type, data} # make it a will, to be handled by next state
    {curr_term(s, data.term) |> role(:FOLLOWER) |> voted_for(nil), true}
  else
    func.(s) # closures function
  end
  # return s
end


# common request handleer

def handle_ape_request(s, data) do
  # Monitor.server(s, "APE_REQUEST not implemented")

  %{:s=> s}
end

def handle_vote_request(s, data) do
  # update s.votedfor

  #assert s.curr_term >= data.term, "should update term and convert to candidate"

  # send reply
  targetP = Enum.at(s.servers, data.candidateId)
  # checkpoint 1
  voteGranted = if data.term < s.curr_term do
    false
  else
    # checkpoint 2
    {lastLogTerm, lastLogIndex} = get_prev_log(s)
    if s.voted_for in [nil, data.candidateId] and (
        (data.lastLogTerm>lastLogTerm) or
        (data.lastLogTerm==lastLogTerm and data.lastLogIndex>=lastLogIndex)
      ) do

      true

    else
      false
    end

  end

  was_vote = s.voted_for

  s = if voteGranted do voted_for(s, data.candidateId) else s end
  reply = %{:term=>s.curr_term, :voteGranted=>voteGranted}

  if voteGranted do
    Monitor.server(s,10,  "vote request from #{data.candidateId}, #{voteGranted}, #{was_vote} -> #{s.voted_for}")
  else
    Monitor.server(s,0,  "vote request from #{data.candidateId}, #{voteGranted}, #{was_vote} -> #{s.voted_for}")
  end

  send targetP, {:VOTE_REPLY, reply }

  Map.put(reply, :s, s )
end

end # State
