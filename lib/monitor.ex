
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1
# Leyang Shen (ls2617)

defmodule Monitor do

def assert(s, bool, reason\\nil) do
  if bool==false do
    throw "ASSERTION ERROR due to #{reason}, #{s}"
  end
end

def notify(s, message) do send s.config.monitorP, message end

def client(s, string) do
 IO.puts "#{Time.to_string(Time.utc_now)}: CLIENT #{s.id}: #{string}"
end # debug

def client(s,level, string) do
  if level >= s.config.debug_level, do: IO.puts "#{Time.to_string(Time.utc_now)}: CLIENT #{s.id}: #{string}"
end # debug


def sinspect(s) do
  leader = if s.role == :LEADER, do: "nextIdx: #{inspect s.next_index}, matchIdx: #{inspect s.match_index},"
  IO.puts("#{s.curr_term}_#{s.role}@#{s.id}: commitIdx: #{s.commit_index}, appliedIdx: #{s.last_applied},#{leader},  log: #{inspect Enum.map(s.log, fn(x) -> [term: elem(x,1), cmd: elem(x,0).cmd, uid: elem(x,0).uid] end), limit: :infinity}")
  send s.databaseP, {:dinspect}
end

def dinspect(d) do
  IO.puts("DATABASE@#{d.server_id}, seqnum: #{d.seqnum}, balances: #{inspect d.balances}")
end

def db(d, string) do #assume highest level
  IO.puts "#{Time.to_string(Time.utc_now)}: DATABASE@#{d.server_id}: #{string}"
end # debug

def server(s, string) do #assume highest level
  IO.puts "#{Time.to_string(Time.utc_now)}: #{s.curr_term}_#{s.role}@#{s.id}: #{string}"
end # debug

def server(s, level, string) do
 if level >= s.config.debug_level do IO.puts "#{Time.to_string(Time.utc_now)}: #{s.curr_term}_#{s.role}@#{s.id}: #{string}" end
end # debug

def pad(key), do: String.pad_trailing("#{key}", 10)

def state(s, level, string) do
 if level >= s.config.debug_level do
   state_out = for {key, value} <- s, into: "" do "\n  #{pad(key)}\t #{inspect value}" end
   IO.puts "\nserver #{s.id} #{s.role}: #{inspect s.selfP} #{string} state = #{state_out}"
 end # if
end # state

def stop(string) do
  IO.puts "HALT: monitor: #{string}"
  System.stop
end

def halt(string) do
  raise "HALT: monitor: #{string}"
end # halt

def halt(s, string) do
  raise "HALT: server #{s.id}: #{string}"
end # halt

def letter(s, letter) do
  if s.config.debug_level == 3, do: IO.write(letter)
end # letter

def start(config) do
  state = %{
    config:             config,
    clock:              0,
    requests:           Map.new,
    updates:            Map.new,
    moves:              Map.new,

    serversP:           List.duplicate(nil, config.n_servers),
    roles:              Map.new,
  }
  Process.send_after(self(), { :PRINT }, state.config.print_after)
  Monitor.next(state)
end # start

defp update_serverP(state, id, p) do
  new_P=List.replace_at(state.serversP, id, p)
  Map.put(state, :serversP, new_P)
end

defp update_roles(state, id, term, role) do
  new_role=Map.put(state.roles, id, {term, role})
  Map.put(state, :roles, new_role)
end

def clock(state, v), do: Map.put(state, :clock, v)

def inc_requests(state, i) do
  new_requests = Map.put(state.requests, i, Map.get(state.requests, i, 0) + 1)
  Map.put(state, :requests, new_requests)
end

def updates(state, i, v), do:
    Map.put(state, :updates,  Map.put(state.updates, i, v))

def moves(state, v), do: Map.put(state, :moves, v)

def next(state) do
  receive do
  { :DB_MOVE, db, seqnum, command}  ->
    { :move, amount, from, to } = command

    done = Map.get(state.updates, db, 0)

    cond do
      seqnum < done + 1 -> :skip # caused when server crashed, and redo all the entry

      seqnum != done + 1 ->
        Monitor.halt "  ** error DATEBASE@#{db}: seq #{seqnum} expecting #{done+1}"

      true-> :skip
    end

    moves =
      case Map.get(state.moves, seqnum) do
      nil ->
        # IO.puts "db #{db} seq #{seqnum} = #{done+1}"
        Map.put state.moves, seqnum, %{ amount: amount, from: from, to: to }

      t -> # already logged - check command
        if amount != t.amount or from != t.from or to != t.to, do:
	  Monitor.halt " ** error DATEBASE@#{db} .#{done} [#{amount},#{from},#{to}] " <>
            "= log #{done}/#{map_size(state.moves)} [#{t.amount},#{t.from},#{t.to}]"
        state.moves
      end # case

    state = Monitor.moves(state, moves)
    state = Monitor.updates(state, db, seqnum)
    Monitor.next(state)

  {:ROLE_UPDATE, id, term, role, serverP} ->
    state = update_roles(state, id, term, role)
            |> update_serverP(id, serverP)
    Monitor.next(state)


  { :CLIENT_REQUEST, server_num } ->  # client requests seen by leader at the time
    state = Monitor.inc_requests(state, server_num)
    Monitor.next(state)

  { :PRINT } ->
    # update clock
    clock  = state.clock + state.config.print_after
    state  = Monitor.clock(state, clock)

    sorted = state.updates  |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock}      db updates done = #{inspect sorted}"
    sorted = state.requests |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock} client requests seen = #{inspect sorted}, (when the node was leader)"
    IO.puts "time = #{clock}        server roles  = #{inspect state.roles}"

    if state.config.debug_level >= 0 do  # always
      min_done   = state.updates  |> Map.values |> Enum.min(fn -> 0 end)
      n_requests = state.requests |> Map.values |> Enum.sum
      IO.puts "time = #{clock}           total seen = #{n_requests} max lag = #{n_requests-min_done}"
    end

    # ask server to give self inspect
    if state.config.show_server do
      for p <- state.serversP |> Enum.filter(&(&1!=nil)) do
        send p, {:sinspect}
      end
    end


    Process.send_after(self(), { :PRINT }, state.config.print_after)
    Monitor.next(state)

  # ** ADD ADDITIONAL MONITORING MESSAGES HERE

  unexpected ->
    Monitor.halt "monitor: unexpected message #{inspect unexpected}"
  end # receive
end # next

end # Monitor

