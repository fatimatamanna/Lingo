#include "lingo/server.h"

#include <httplib.h>
#include <nlohmann/json.hpp>

namespace lingo {

void register_routes(httplib::Server& server) {
    server.Get("/api/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_content(nlohmann::json{{"ok", true}}.dump(), "application/json");
    });
}

}  // namespace lingo
