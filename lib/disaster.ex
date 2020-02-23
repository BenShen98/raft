
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

# Leyang Shen(ls2617)

defmodule Disaster do

def handle(s, d) do
  Monitor.server(s,40, "AFFECTED BY #{d.type}")
  case d.type do
    "offline" ->
      offline(s)

    "crash" ->
      crash(s)

    "timeout" ->
      timeout(s)

    t when t in ["online"] ->
      Monitor.server(s,30, "ERROR: disaster #{t} has no effect")
  end

end

defp timeout(s) do
  s=State.force_election_timeout(s)
  {s, false}
end

defp offline(s) do
  # DOES NOT MODIFY s

  escape=receive do
    {:disaster, d}->
      if d.type=="online" do
        Monitor.server(s,40, "AFFECTED BY #{d.type}")
        true
      else
        Monitor.server(s,30,"ERROR: after offline or crash, only online are accpted")
        false
      end

    msg->
      Monitor.server(s, 0, "offline: #{inspect msg}")
      false

  end

  if escape do
    # restart server FSM
    {s, true}
  else
    offline(s)
  end
end

defp crash(s) do
  State.initialise(s.config, s.id, s.servers, s.databaseP)
  |> offline()
end

end # module -----------------------
