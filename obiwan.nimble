# Package

version       = "0.2.0"
author        = "Corvin Wimmer"
description   = "A lightweight Gemini protocol client and server library in Nim."
license       = "All Rights Reserved"
srcDir        = "src"

# Dependencies

requires "nim >= 2.2.2"
requires "nimcrypto >= 0.6.2"

task client, "Build sync client":
  exec "nim c -o:build/client src/obiwan/client/sync.nim"

task asyncclient, "Build async client":
  exec "nim c -o:build/async_client src/obiwan/client/async.nim"

task server, "Build sync server":
  exec "nim c -o:build/server src/obiwan/server/sync.nim"

task asyncserver, "Build async server":
  exec "nim c -o:build/async_server src/obiwan/server/async.nim"

task buildall, "Build all":
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"
  
  # Now build the ObiWAN components
  exec "nim c -o:build/client src/obiwan/client/sync.nim"
  exec "nim c -o:build/async_client src/obiwan/client/async.nim"
  exec "nim c -o:build/server src/obiwan/server/sync.nim"
  exec "nim c -o:build/async_server src/obiwan/server/async.nim"

task test, "Run all tests in sequence":
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"
  
  # Ensure certificates are properly set up
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"

  echo "\nCompiling all tests in parallel..."
  # Create build directory if it doesn't exist
  exec "mkdir -p " & thisDir() & "/build"

  # First, compile all tests in parallel with streaming output
  exec """
    cd """ & thisDir() & """ &&
    printf "\n===== Compiling All Tests in Parallel =====\n" &&
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_url_parsing tests/test_url_parsing.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_protocol tests/test_protocol.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_server tests/test_server.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_client tests/test_client.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_real_server tests/test_real_server.nim &

    # Wait for all compilations to complete
    wait
  """

  # Now run each test in sequence
  echo "\nRunning all tests sequentially..."

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_url_parsing"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_protocol"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_server"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_client"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_real_server"

  # Note: TLS tests have indentation issues that need fixing
  # echo "\nRunning TLS tests..."
  # exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --hints:off --path:src tests/test_tls.nim"

  # Note: IPv6 tests are experimental and may need more work
  # echo "\nRunning IPv6 tests..."
  # exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --hints:off --path:src tests/ipv6_test.nim"

task testparallel, "Run all tests in parallel":
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"
    
  # Ensure certificates are properly set up
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"

  # Create build directory if it doesn't exist
  exec "mkdir -p " & thisDir() & "/build"

  # First compile all tests in parallel
  echo "\nCompiling all tests in parallel..."
  exec """
    cd """ & thisDir() & """ &&
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_url_parsing tests/test_url_parsing.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_protocol tests/test_protocol.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_server tests/test_server.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_client tests/test_client.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_real_server tests/test_real_server.nim &

    # Wait for all compilations to complete
    wait
  """

  # Run all tests at once for maximum speed
  # Note output will be out of order
  echo "\nRunning all tests in parallel for maximum speed...\n"
  exec """
    cd """ & thisDir() & """ &&
    SKIP_CERT_GEN=1 ./build/test_url_parsing &
    SKIP_CERT_GEN=1 ./build/test_protocol &
    SKIP_CERT_GEN=1 ./build/test_server &
    SKIP_CERT_GEN=1 ./build/test_client &
    SKIP_CERT_GEN=1 ./build/test_real_server &
    wait
  """

task testserver, "Run server tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_server.nim"

task testclient, "Run client tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  # Pass environment variables to prevent regeneration of certificates
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release -w:off --hints:off --path:src tests/test_client.nim"

task testcertauth, "Run client certificate auth tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release -w:off --hints:off --path:src tests/test_real_server.nim"

task testtls, "Run TLS tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_tls.nim"

task testurl, "Run URL parsing tests":
  exec "cd " & thisDir() & " && nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_url_parsing.nim"

task testprotocol, "Run protocol compliance tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c --parallelBuild:0 -d:release -r --hints:off --path:src tests/test_protocol.nim"

task buildmbedtls, "Build the vendored mbedTLS library":
  echo "Building vendored mbedTLS 3.6.2..."
  exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"
  echo "mbedTLS build complete."

task testhelp, "Show information about test tasks":
  echo """
ObiWAN Testing Options
======================

This project offers multiple ways to run tests with different trade-offs:

1. nimble test
   - Compiles all tests in parallel, then runs them sequentially
   - Output is clean and organized by test
   - Good balance between speed and readability
   - Default option for most development work

3. nimble testparallel
   - Maximum speed: compiles and runs all tests in parallel
   - Output is interleaved but preserves colors
   - Fastest option but output may be mixed

Individual test tasks:
- nimble testurl      - Run only URL parsing tests
- nimble testprotocol - Run only protocol tests
- nimble testserver   - Run only server tests
- nimble testclient   - Run only client tests
- nimble testcertauth - Run only client certificate tests
- nimble testtls      - Run only TLS tests (currently disabled)

All tests use parallel compilation with --parallelBuild:0 flag to utilize all CPU cores.
"""
