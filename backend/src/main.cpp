#include <httplib.h>
#include <nlohmann/json.hpp>

#include <iostream>

int main() {
    constexpr const char* kHost = "127.0.0.1";
    constexpr int kPort = 8080;

    httplib::Server server;

    server.Get("/api/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_content(nlohmann::json{{"ok", true}}.dump(), "application/json");
    });

    std::cout << "Lingo server listening on http://" << kHost << ":" << kPort << std::endl;
    if (!server.listen(kHost, kPort)) {
        std::cerr << "Failed to listen on " << kHost << ":" << kPort
                  << " (is another server already using the port?)" << std::endl;
        return 1;
    }
    return 0;
}
