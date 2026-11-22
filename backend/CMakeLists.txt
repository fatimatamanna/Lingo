cmake_minimum_required(VERSION 3.20)
project(lingo LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Single-config generators (Make/Ninja on macOS/Linux) default to an unoptimized
# build, which makes whisper.cpp many times slower. Default to Release there.
# Multi-config generators (Visual Studio, Xcode) pick it with --config instead.
get_property(LINGO_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT LINGO_MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Build every dependency as a static library. On Windows this keeps whisper/ggml
# out of separate DLLs, so lingo_server.exe and lingo_tests.exe run without
# copying DLLs next to them.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

include(FetchContent)

# --- cpp-httplib (HTTP server) -----------------------------------------------
# Plain HTTP on localhost only: don't pick up OpenSSL/zlib/brotli even if installed.
set(HTTPLIB_USE_OPENSSL_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
set(HTTPLIB_USE_ZLIB_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
set(HTTPLIB_USE_BROTLI_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
FetchContent_Declare(httplib
  URL https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.18.1.tar.gz
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)

# --- nlohmann/json -----------------------------------------------------------
FetchContent_Declare(json
  URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)

# --- GoogleTest --------------------------------------------------------------
# Use the same C runtime (/MD) as the rest of the project on MSVC.
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_Declare(googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.zip
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)

FetchContent_MakeAvailable(httplib json googletest)

# --- whisper.cpp (git submodule, never edited) -------------------------------
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
# On Apple Silicon whisper.cpp uses Metal (GPU) by default, with the shaders
# embedded in the binary, so nothing extra is needed. Don't turn GGML_METAL off.
add_subdirectory(third_party/whisper.cpp)
if(APPLE)
  message(STATUS "Lingo: whisper.cpp Metal = ${GGML_METAL}, Accelerate BLAS = ${GGML_BLAS}")
endif()

# --- lingo_core: everything except main(), shared by server and tests --------
file(GLOB LINGO_CORE_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp)
list(REMOVE_ITEM LINGO_CORE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp)

add_library(lingo_core STATIC ${LINGO_CORE_SOURCES})
target_include_directories(lingo_core PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/third_party/whisper.cpp/examples)
target_link_libraries(lingo_core PUBLIC
  httplib::httplib
  nlohmann_json::nlohmann_json
  whisper)

# --- lingo_server ------------------------------------------------------------
add_executable(lingo_server src/main.cpp)
target_link_libraries(lingo_server PRIVATE lingo_core)

# --- lingo_tests -------------------------------------------------------------
enable_testing()
include(GoogleTest)

file(GLOB LINGO_TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/tests/*.cpp)
add_executable(lingo_tests ${LINGO_TEST_SOURCES})
target_link_libraries(lingo_tests PRIVATE lingo_core GTest::gtest_main)
gtest_discover_tests(lingo_tests)
