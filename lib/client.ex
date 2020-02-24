
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

defmodule Client do

def start(config, client_id, servers) do
  c = %{
    config:     config,
    id:         client_id,
    servers:    servers,
    leaderP:    Enum.random(servers),  # randomly pick a server
    cmd_seqnum: 0,
  }
  Process.send_after(self(), { :CLIENT_STOP }, c.config.client_stop)
  Client.next(c)
end # start

def stop(c) do
   System.stop(0)
end # stop

def next(c) do
  {c, terminate} =
    receive do
      { :CLIENT_STOP } ->
        {c, true}

    after c.config.client_sleep ->
      account1  = Enum.random 1 .. c.config.n_accounts
      account2  = Enum.random 1 .. c.config.n_accounts
      amount    = Enum.random 1 .. c.config.max_amount

      cmd  = { :move, amount, account1, account2 }
      c    = Map.put(c, :cmd_seqnum, c.cmd_seqnum + 1)
      uid  = { c.id, c.cmd_seqnum }              # unique id for cmd

      client_request = { :CLIENT_REQUEST, %{clientP: self(), uid: uid, cmd: cmd } }

      Monitor.client(c, 10, "send to server: #{inspect client_request}")

      Client.send_request(c, client_request)  # result not used
    end # receive

  if terminate==false do
    Client.next(c)
  else
    Monitor.stop "Client #{c.id} going to sleep, sent = #{c.cmd_seqnum}"
  end

end # next

def send_request(c, client_request) do
  send c.leaderP, client_request

  receive do
  { :CLIENT_REPLY, result } ->
    c  = Map.put(c, :leaderP, result.leaderP)  # update leaderP

    # check is right response
    if elem(client_request,1).uid == result.uid do
      # reply for the correct uid
      if c.cmd_seqnum == c.config.client_requests do
        {c, true} # exit
      else
        {c, false} # continue
      end

    else
      # reply to wrong uid, ignore and retry
      Monitor.client(c, 30, "expecting #{inspect elem(client_request,1).uid} reply, get #{inspect result.uid}")
      Client.send_request(c, client_request)
    end




  { :CLIENT_STOP } ->
    {c, true}

  after c.config.client_timeout ->
    # leader probably crashed, retry command with different server
    non_leader = for server <- c.servers, server != c.leaderP do server end
    c = Map.put(c, :leaderP, Enum.random(non_leader))
    Client.send_request(c, client_request)
  end # receive
end # send_command

end # Client

