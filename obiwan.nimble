# Package

version       = "0.1.0"
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
