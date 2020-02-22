
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

defmodule Raft do

def start do
  config = DAC.node_init()

  Raft.start(config.start_function, config)
end # start/0

def start(:multi_node_wait, _), do: :skip

def start(:multi_node_start, config) do
  # spawn monitor process in top-level raft node
  monitorP = spawn(Monitor, :start, [config])
  config   = Map.put(config, :monitorP, monitorP) |> Map.put(:raftP, self())

  IO.puts("====RUNNNING WITH CONFIG====")
  IO.puts(inspect config)
  IO.puts("====   CONFIG    END   ====")

  # co-locate 1 server and 1 database at each server node
  servers = for id <- 0 .. config.n_servers-1 do # such serverP = servers[id]
    databaseP = Node.spawn(:'server#{id}_#{config.node_suffix}',
                     Database, :start, [config, id])
    _serverP  = Node.spawn(:'server#{id}_#{config.node_suffix}',
                     Server, :start, [config, id, databaseP])
  end # for

  # plan for attack
  for disaster <- config.disasters do
    Process.send_after( self(), {:disaster, disaster}, disaster.t)
  end

  # pass list of servers to each server
  for server <- servers, do: send server, { :BIND, servers }

  # create 1 client at each client node
  for id <- 0 .. config.n_clients-1 do
    _clientP = Node.spawn(:'client#{id}_#{config.node_suffix}',
                    Client, :start, [config, id, servers])
  end # for

  next(servers, %{"leader"=>nil})
end

defp next(servers, refs) do
  refs = receive do
    {:disaster, disaster}=msg ->
      target_id=cond do
        # raw reference
        is_integer(disaster.id) ->
          send Enum.at(servers, disaster.id), msg
          disaster.id

        # lookup reference
        (server_id=Map.get(refs, disaster.id, nil)) != nil ->
          send Enum.at(servers, server_id), msg
          server_id
      end

      new_ref = Map.get(disaster, :ref)
      if new_ref != nil do
        Map.put(refs, new_ref, target_id)
      else
        refs
      end

    {:leader_start, leader} ->
      Map.put(refs, "leader", leader)

    msg ->
      IO.puts("unexpected msg to raft #{inspect msg}")
      System.stop
  end

  IO.puts("Disaster reference name #{inspect refs}")
  next(servers, refs)
end

end # module ------------------------------


