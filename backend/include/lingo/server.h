#pragma once

namespace httplib {
class Server;
}

namespace lingo {

// Registers every Lingo HTTP route on `server`.
// main.cpp uses this for the real server; tests use it to spin up a test server.
void register_routes(httplib::Server& server);

}  // namespace lingo
