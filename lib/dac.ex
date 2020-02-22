
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

# various helper functions

defmodule DAC do

def node_ip_addr do
  {:ok, interfaces} = :inet.getif()		# get interfaces
  {address, _gateway, _mask}  = hd(interfaces)	# get data for 1st interface
  {a, b, c, d} = address   			# get octets for address
  "#{a}.#{b}.#{c}.#{d}"
end

def random(n), do: Enum.random 1..n

# --------------------------------------------------------------------------

def node_exit do 	# nicely stop and exit the node
  System.stop(0)	# System.halt(1) for a hard non-tidy node exit
end

def exit_after(duration) do
  Process.sleep(duration)
  IO.puts "Exiting #{node()}"
  node_exit()
end

def node_init do  # get node arguments and spawn a process to exit node after max_time
  config = Map.new
  config = Map.put config, :max_time, 	  String.to_integer(Enum.at(System.argv, 0))
  config = Map.put config, :node_suffix,  Enum.at(System.argv, 1)
  config = Map.put config, :n_servers, 	  String.to_integer(Enum.at(System.argv, 2))
  config = Map.put config, :n_clients, 	  String.to_integer(Enum.at(System.argv, 3))
  config = Map.put config, :start_function, :'#{Enum.at(System.argv, 4)}'



  config = config
  |> more_parameters()
  |> load_config(Enum.at(System.argv, 5)) # read from config file, override exist

  spawn(DAC, :exit_after, [config.max_time])
  config
end

defp more_parameters(config) do
  Map.merge config, %{

    debug_level:     10,         # debug level, use 0 DEBUG, 10 LOG, 20 WARNING, 30 ERROR, 40 MANMADE DISASTER
    print_after:     2_000,     # print transaction log summary every print_after millisecs

    client_requests: 1,    	# max requests each client will make
    client_sleep:    5,        	# time to sleep before sending next request
    client_stop:     60_000,  	# time after which client should stop sending requests
    client_timeout:  500,       # timeout for expecting reply to client request

    n_accounts:      100,	# number of active bank accounts
    max_amount:      1_000,	# max amount moved between accounts

    election_timeout: 100,	# timeout(ms) for election, randomly from this to 2*this value
    append_entries_timeout: 10, # timeout(ms) for expecting reply to append_entries request

    disasters: [],

  }
end

defp load_config(default_config, filename) do

  if filename == nil do
    default_config
  else
    config_from_file = filename
    |> File.read!
    |> Poison.Parser.parse!(%{keys: :atoms!})

    for key <- Map.keys(default_config), into: %{} do
      {key, Map.get(config_from_file, key, Map.get(default_config, key))}
    end

  end

end

end # module -----------------------
