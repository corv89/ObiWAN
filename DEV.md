# ObiWAN Development Guide

## Build Commands
- Library: `nim c src/obiwan.nim`
- Build all: `nimble buildall`
- Sync client: `nimble client` or `nim c -o:build/client src/obiwan/client/sync.nim`
- Async client: `nimble asyncclient` or `nim c -o:build/async_client src/obiwan/client/async.nim`
- Sync server: `nimble server` or `nim c -o:build/server src/obiwan/server/sync.nim`
- Async server: `nimble asyncserver` or `nim c -o:build/async_server src/obiwan/server/async.nim`
- Run with args: `nim c -r src/obiwan/client/sync.nim gemini://server/path`
- Generate documentation: `nimble docs`
- Generate bindings: `nimble bindings`

## Code Style Guidelines
- **Indentation**: 2 spaces
- **Naming**: Types use CamelCase (with * for export), procs/vars use camelCase
- **Imports**: Standard lib first, then external deps, finally local modules
- **Types**: Use generics for shared sync/async behavior
- **Error handling**: Use GeminiError (inherits from CatchableError)
- **Documentation**: Docstrings for public procs, document parameters
- **TLS**: Follow TOFU (Trust On First Use) principles for certificates
