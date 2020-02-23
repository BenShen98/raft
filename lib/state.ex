
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
    log:          [], # stores {payload, term} pair, payload=%{:clientP=>, :cmd=>cmd, :uid=>uid}

    # -- raft non-persistent data
    role:	  :FOLLOWER, # LEADER,FOLLOWER,CANDIDATE
    commit_index: 0, # index of last commited log
    last_applied: 0, # index of log excuted to db

    # -- leader specfic
    next_index:   nil,
    match_index:  nil,

    # -- follower/candidate
    leader: nil,
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
  # NOTE: log_index_for_last_log = length(s.log)
  get_log(s, length(s.log) )
end

def get_prev_log(s, new_log_index) do
  get_log(s, new_log_index-1)
end

def get_log(s, log_index) do
  # returns {term, log_index}
  cond do
    log_index < 0 ->
      Monitor.halt(s, "invalid log index")
      log_index == 0 ->
      {0, 0} #base case for first new log
    true ->
      {Enum.at(s.log, log_index-1) |> elem(1), log_index}
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
# def next_index(s, v),     do: Map.put(s, :next_index, v)      # sets new next_index map
# def next_index(s, i, v),  do: Map.put(s, :next_index,
#                                   Map.put(s.next_index, i, v))
# def match_index(s, v),    do: Map.put(s, :match_index, v)     # sets new  match_index map
# def match_index(s, i, v), do: Map.put(s, :match_index,
#                                   Map.put(s.match_index, i, v))

# add additional setters
def inc_term(s), do: Map.put(s, :curr_term, s.curr_term+1)
def inc_vote(s), do: Map.put(s, :votes, s.votes+1)

def next_index(s, id, v), do: Map.put(s, :next_index, :erlang.setelement(id+1,s.next_index, v ))
def match_index(s, id, v), do: Map.put(s, :match_index, :erlang.setelement(id+1,s.match_index, v ))
def dec_next_index(s, id) do
  IO.puts("dec #{inspect s}")
  s=next_index(s, id, elem(s.next_index, id)-1)
  IO.puts("dec #{inspect s}")
  s
end

defp append_logs(s, entries) do # for follower
  new_logs = for entry <- entries do
    {entry, s.curr_term}
  end
  Map.put(s, :log, s.log ++ new_logs)
end

def apply_commited_log(s) do
  if s.last_applied < s.commit_index do
    for log_index <- s.last_applied+1 .. s.commit_index do
      send s.databaseP, {:EXECUTE, Enum.at(s.log, log_index-1) |> elem(0) |> Map.get(:cmd) }
    end
    last_applied(s, s.commit_index)
  else
    s
  end
end

defp update_commit_index(s, leaderCommit) do # for follower
  if leaderCommit>s.commit_index do
    commit_index(s, min(leaderCommit, length(s.log) ))
  else
    s
  end
end

# helper function

# common guard function
def check_term_and(s,type,data, func) do
  if data.term > s.curr_term do
    Monitor.server(s,10, "Higher term found #{ inspect {type,data}}")
    send self(), {type, data} # make it a will, to be handeled by next state
    {curr_term(s, data.term) |> role(:FOLLOWER) |> voted_for(nil), true}
  else
    func.(s) # closures function
  end
  # return s
end


# common request handeler
def forward_client_request(s, payload) do
  if s.leader == nil do
    Monitor.server(s, 20, "ignore client request while dont know leader")
  else
    send Enum.at(s.servers, s.leader), {:CLIENT_REQUEST, payload}
  end

  s
end

def handel_ape_request(s, data) do
  # BUG: should commit_index updated before applied

  targetP = Enum.at(s.servers, data.leaderId)
  s = Map.put(s, :leader, data.leaderId)


  {success, s} = cond do
    data.term > s.curr_term ->
      Monitor.halt(s, "assertion s.curr_term >= data.term failed")

    data.term < s.curr_term ->
      {false, s}

    length(s.log) < data.prevLogIndex -> # length(s.log) == last_log_index
      # previous entry does not exist in current follower
      {false, s}

    get_log(s, data.prevLogIndex) == {data.prevLogTerm, data.prevLogIndex} ->
      # previous log matches
      Monitor.assert s, s.curr_term==data.term
      {true, append_logs(s, data.entries) |> update_commit_index(data.leaderCommit) |> apply_commited_log() } # NOTE:new log has the current term

    get_log(s, data.prevLogIndex)|>elem(0) > data.prevLogTerm -> # TO BE REMOVED
      Monitor.server(s, "ERROR?????? this #{inspect get_log(s, data.prevLogIndex)}|>elem(0) > #{data.prevLogTerm} should not happen\n\t\tdata: #{inspect data},\n\t\ts: #{inspect s},")
      # existing entry conflicts, delete it and what follows
      {l, _}=Enum.split(s.log, data.prevLogIndex-1)
      {false, Map.put(s, :log, l)}

    true ->
      # existing entry conflicts, delete it and what follows
      {l, _}=Enum.split(s.log, data.prevLogIndex-1)
      {false, Map.put(s, :log, l)}

  end

  reply=%{:term => s.curr_term, :success=>success, :id=>s.id, :length=>length(data.entries)}

  send targetP, {:APE_REPLY, reply}

  if success and length(data.entries)>0 do
    Monitor.server(s,10,  "accept #{inspect data}")
  end

  Map.put(reply, :s, s)
end

def handel_vote_request(s, data) do
  # update s.votedfor

  Monitor.assert s, s.curr_term >= data.term, "should update term and convert to candidate"

  # send reply
  targetP = Enum.at(s.servers, data.candidateId)
  # checkpoint 1
  voteGranted = if data.term < s.curr_term do
    false
  else
    # checkpoint 2
    {lastLogTerm, lastLogIndex} = get_last_log(s)
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
