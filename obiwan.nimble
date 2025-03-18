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
  exec "nim c -o:build/client src/obiwan/client/sync.nim"
  exec "nim c -o:build/async_client src/obiwan/client/async.nim"
  exec "nim c -o:build/server src/obiwan/server/sync.nim"
  exec "nim c -o:build/async_server src/obiwan/server/async.nim"

task test, "Run all tests":
  # First ensure certificates are properly set up
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  
  echo "\nRunning URL parsing tests..."
  exec "cd " & thisDir() & " && nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_url_parsing.nim"
  
  echo "\nRunning protocol tests..."
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c --parallelBuild:0 -d:release -r --hints:off --path:src tests/test_protocol.nim"
  
  echo "\nRunning server tests..."
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_server.nim"
  
  echo "\nRunning client tests..."
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release -w:off --hints:off --path:src tests/test_client.nim"
  
  echo "\nRunning client certificate tests..."
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release -w:off --hints:off --path:src tests/test_real_server.nim"
  
  # Note: TLS tests have indentation issues that need fixing
  # echo "\nRunning TLS tests..."
  # exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --hints:off --path:src tests/test_tls.nim"
  
  # Note: IPv6 tests are experimental and may need more work
  # echo "\nRunning IPv6 tests..."
  # exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --hints:off --path:src tests/ipv6_test.nim"

task paralleltest, "Run all tests in parallel":
  # First ensure certificates are properly set up
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  
  echo "\nRunning all tests in parallel..."
  # Create build directory if it doesn't exist
  exec "mkdir -p " & thisDir() & "/build"
  
  # Using --parallelBuild:0 for parallel compilation (uses all CPU cores)
  # Running tests in parallel with background processes
  exec """
    cd """ & thisDir() & """ && 
    (nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_url_parsing tests/test_url_parsing.nim && 
     SKIP_CERT_GEN=1 ./build/test_url_parsing) &
    
    (nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_protocol tests/test_protocol.nim && 
     SKIP_CERT_GEN=1 ./build/test_protocol) &
    
    (nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_server tests/test_server.nim && 
     SKIP_CERT_GEN=1 ./build/test_server) &
    
    (nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_client tests/test_client.nim && 
     SKIP_CERT_GEN=1 ./build/test_client) &
    
    (nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_real_server tests/test_real_server.nim && 
     SKIP_CERT_GEN=1 ./build/test_real_server) &
    
    # Wait for all background processes to complete
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
