{
    "description": "Testing voting system, 3 out of 5 servers will fail one by one. In the end, one of the failed server will recover",
    "n_clients":0,
    "n_servers":5,
    "show_server": false,
    "disasters": [
        {"t":0, "type":"timeout", "id":0},
        {"t":1000, "type":"offline", "id":"leader", "ref":"a"},
        {"t":1500,"type":"crash", "id":"leader", "ref":"b"},
        {"t":2000,"type":"offline", "id":"leader", "ref":"c"},
        {"t":2500,"type":"online", "id":"b"}
    ],
    "debug_level":10
}
