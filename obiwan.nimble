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
  echo "Running URL parsing tests..."
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_url_parsing.nim"
  
  echo "\nRunning protocol tests..."
  exec "cd " & thisDir() & " && nim c -d:release -r --hints:off --path:src tests/test_protocol.nim"
  
  echo "\nRunning server tests..."
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_server.nim"
  
  echo "\nRunning client tests..."
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_client.nim"
  
  # Note: TLS tests have indentation issues that need fixing
  # echo "\nRunning TLS tests..."
  # exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_tls.nim"
  
  # Note: IPv6 tests are experimental and may need more work
  # echo "\nRunning IPv6 tests..."
  # exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/ipv6_test.nim"

task testserver, "Run server tests":
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_server.nim"

task testclient, "Run client tests":
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_client.nim"

task testtls, "Run TLS tests":
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_tls.nim"

task testurl, "Run URL parsing tests":
  exec "cd " & thisDir() & " && nim c -r --hints:off --path:src tests/test_url_parsing.nim"

task testprotocol, "Run protocol compliance tests":
  exec "cd " & thisDir() & " && nim c -d:release -r --hints:off --path:src tests/test_protocol.nim"
