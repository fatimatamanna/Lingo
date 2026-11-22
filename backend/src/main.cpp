#include "lingo/server.h"

#include <httplib.h>

#include <iostream>

int main() {
    constexpr const char* kHost = "127.0.0.1";
    constexpr int kPort = 8080;

    httplib::Server server;
    lingo::register_routes(server);

    std::cout << "Lingo server listening on http://" << kHost << ":" << kPort << std::endl;
    if (!server.listen(kHost, kPort)) {
        std::cerr << "Failed to listen on " << kHost << ":" << kPort
                  << " (is another server already using the port?)" << std::endl;
        return 1;
    }
    return 0;
}
