# Raft


## Installation and Execution

To run this implementation with default settings, run the following commands:
make clean
make run run_multi

To run the test suite, run the following commands:
chmod +x script/test.sh
script/test.sh

### config.json
List of all possible parameters

| Parameter Name | Default (value in dac.ex) | Description
|----------------|:-------------------------:|-----------:|
| max_time | 10000 | Maximum execution time
| n_servers | 5 | Number of servers
| n_clients | 5 | Number of clients
| start_function | Raft.start | Program start function
| debug_level | 20 | Level of debugging, 0(Debug), 10 (Log), 20(Warnings), 30(Errors), 40(Disasters)
| show_server | true | Prints server and database content
| show_role_switch | true | Shows when servers change between leader, candidate, follower roles
| print_after | 2_000 | Interval for printing transaction log summary(in milliseconds)
| client_requests | 100 | Max requests each client will make
| client_sleep | 5 | Time to sleep before sending next requests
| client_stop | 60_000 | Time after which client should stop requests(in milliseconds)
| client_timeout | 500 | Client timeout for expecting reply
| n_accounts | 100 | Number of active bank accounts
| max_amount | 1_000 | Max amount moved between accounts
| election_timeout | 100 | Timeout(in milliseconds) for elections, randomly chosen between this and 2\*this
| append_entries_timeout | 10 | Timeout(in milliseconds) for expecting a reply to append_entries requests
| disasters | [] | List of disasters to force system changes

### Disaster format
Disasters are a list of actions to force changes in the system, such that failures or other conditions can be simulated
It contains the following parameters
| Parameter Name | Possible Values | Description
|----------------|:---------------:|-----------:|
| t | (int) | Time to execute the disaster(in milliseconds)
| type | "timeout", "crash", "offline", "online" | Type of disaster, defined in report 
| id | (int), "leader", (string) | Server ID for disaster, int will be the node number, "leader" refers to the current leader, while a string can be used if a server ref has been declared previously
| ref | (string) | Reference to tag a particular node, such that it can be called by that reference in future
