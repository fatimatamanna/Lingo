#include "lingo/server.h"

#include <gtest/gtest.h>
#include <httplib.h>
#include <nlohmann/json.hpp>

#include <thread>

namespace {

// Starts the real Lingo routes on a free localhost port for the duration of a test.
class LingoServerTest : public ::testing::Test {
protected:
    void SetUp() override {
        lingo::register_routes(server_);
        port_ = server_.bind_to_any_port("127.0.0.1");
        ASSERT_GT(port_, 0) << "could not bind a localhost port";
        thread_ = std::thread([this] { server_.listen_after_bind(); });
        server_.wait_until_ready();
    }

    void TearDown() override {
        server_.stop();
        if (thread_.joinable()) thread_.join();
    }

    httplib::Client client() const {
        httplib::Client c("127.0.0.1", port_);
        c.set_connection_timeout(2);
        c.set_read_timeout(2);
        return c;
    }

    httplib::Server server_;
    std::thread thread_;
    int port_ = 0;
};

}  // namespace

TEST_F(LingoServerTest, HealthReturnsOkTrueAsJson) {
    auto res = client().Get("/api/health");
    ASSERT_TRUE(res) << "request failed: " << httplib::to_string(res.error());

    EXPECT_EQ(res->status, 200);
    EXPECT_EQ(res->get_header_value("Content-Type"), "application/json");

    const auto body = nlohmann::json::parse(res->body);
    EXPECT_EQ(body, nlohmann::json({{"ok", true}}));
}

TEST_F(LingoServerTest, UnknownRouteReturns404) {
    auto res = client().Get("/api/does-not-exist");
    ASSERT_TRUE(res) << "request failed: " << httplib::to_string(res.error());
    EXPECT_EQ(res->status, 404);
}
