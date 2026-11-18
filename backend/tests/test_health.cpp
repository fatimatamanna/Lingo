#include <gtest/gtest.h>
#include <nlohmann/json.hpp>

// Trivial test: proves GoogleTest, nlohmann/json and lingo_core link together.
TEST(Health, ResponseBodyIsOkTrue) {
    EXPECT_EQ(nlohmann::json({{"ok", true}}).dump(), R"({"ok":true})");
}
