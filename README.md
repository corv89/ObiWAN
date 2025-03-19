# ObiWAN

A lightweight Gemini protocol client and server library in Nim.

## What is ObiWAN?

ObiWAN is a comprehensive library for building clients and servers that speak the [Gemini protocol](https://geminiprotocol.net/docs/specification.html), a lightweight alternative to HTTP designed for simplicity and privacy. The library provides both synchronous and asynchronous APIs with a clean, type-safe interface.

## Features

- **Complete Gemini Protocol Support**: Full implementation of the Gemini protocol specification
- **Dual API**: Both synchronous and asynchronous interfaces
- **TLS Security**: Modern TLS 1.3 implementation using mbedTLS
- **Certificate Handling**: Support for client and server certificates with self-signed cert verification
- **IPv4 and IPv6 Support**: Handles both IP protocol versions with dual-stack support (when supported by OS)
- **Resource Efficient**: Minimal memory footprint and CPU usage
- **Type Safety**: Leverages Nim's strong typing and generics for safe, expressive code

## Installation

### Prerequisites

- Nim 2.2.2 or later
- mbedTLS 3.6.2 (vendored as a git submodule)

### MbedTLS

ObiWAN uses mbedTLS 3.6.2 that is included as a git submodule. When you clone the repository, make sure to include submodules:

```bash
git clone --recurse-submodules https://github.com/corv89/ObiWAN.git
```

Or if you already cloned the repository:

```bash
git submodule update --init
```

The build system will automatically build mbedTLS when needed, or you can build it manually with:

```bash
nimble buildmbedtls
```

### Installing Nim

On macOS:
```bash
brew install nim
```

On Linux:
```bash
# Debian/Ubuntu
sudo apt install nim
```

### Installing ObiWAN dependencies

This will let you generate bindings for languages other than Nim.

```bash
nimble develop
```

### Installing ObiWAN

Install the ObiWAN package if you want to call it from Nim.

```bash
nimble install https://github.com/corv89/ObiWAN
```

Or add to your .nimble file:
```
requires "obiwan >= 0.1.0"
```

## Generating Certificates

Generate a self-signed certificate to run the server

```bash
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -keyout certs/privkey.pem -out certs/cert.pem -days 365 -nodes
```

## Quick Start

### Running ObiWAN

First, build all the programs:

```bash
# Build all clients and servers
nimble buildall
```

Then you can run with the new command-line interface:

```bash
# Show client help
./build/client --help

# Run synchronous client
./build/client gemini://geminiprotocol.net/

# Run asynchronous client with options
./build/async_client --verbose gemini://geminiprotocol.com/

# Run synchronous server with options
./build/server --port=1966 --docroot=./my-content

# Run server with IPv6 support
./build/server --ipv6

# Run asynchronous server with certificate options
./build/async_server --cert=mycert.pem --key=mykey.pem
```

### Command Line Options

ObiWAN provides a comprehensive command-line interface for both clients and servers:

#### Client Options

```
Options:
  -h --help               Show this help screen
  -v --verbose            Increase verbosity level
  -c --config=<file>      Use specific config file
  -r --redirects=<num>    Maximum number of redirects [default: 5]
  --cert=<file>           Client certificate file for authentication
  --key=<file>            Client key file for authentication
  --version               Show version information
```

#### Server Options

```
Options:
  -h --help               Show this help screen
  -v --verbose            Increase verbosity level
  -c --config=<file>      Use specific config file
  -p --port=<port>        Port to listen on [default: 1965]
  -a --address=<addr>     Address to bind to [default: 0.0.0.0]
  -6 --ipv6               Use IPv6 instead of IPv4
  -r --reuse-addr         Allow reuse of local addresses [default: true]
  --reuse-port            Allow multiple bindings to same port
  --cert=<file>           Server certificate file [default: cert.pem]
  --key=<file>            Server key file [default: privkey.pem]
  --docroot=<dir>         Document root directory [default: ./content]
  --version               Show version information
```

### Configuration Files

ObiWAN supports TOML configuration files. By default, it looks for a file named `obiwan.toml` in:

1. The current directory
2. `~/.config/obiwan/config.toml`
3. `/etc/obiwan/config.toml`

You can also specify a config file using the `--config` option:

```bash
./build/server --config=myconfig.toml
./build/client --config=myconfig.toml gemini://example.com/
```

Command-line options override values from the configuration file.

Example configuration:

```toml
# ObiWAN Gemini Server Configuration

[server]
address = "0.0.0.0"
port = 1965
cert_file = "cert.pem"
key_file = "privkey.pem"
reuse_addr = true
reuse_port = false
use_ipv6 = false
session_id = ""
doc_root = "./content"
log_requests = true
max_request_length = 1024

[client]
cert_file = ""
key_file = ""
max_redirects = 5
timeout = 30
user_agent = "ObiWAN/0.3.0"

[log]
level = 1
file = ""
timestamp = true
```

### Client Usage

#### Synchronous Client

```nim
import obiwan

# Create a synchronous client
let client = newObiwanClient()

# Make a request to a Gemini server
let response = client.request("gemini://geminiprotocol.net/")

# Display response information
echo "Status: ", response.status
echo "Meta: ", response.meta

# Check certificate information
if response.hasCertificate:
  echo "Server certificate: ", response.certificate.commonName
  echo "Certificate verified: ", response.isVerified

# Get response body
let body = response.body

# Always close when done
client.close()
```

#### Asynchronous Client

```nim
import obiwan
import asyncdispatch

# Create an asynchronous client
let client = newAsyncObiwanClient()

proc main() {.async.} =
  # Make a request to a Gemini server
  let response = await client.request("gemini://geminiprotocol.net/")

  # Display response information
  echo "Status: ", response.status
  echo "Meta: ", response.meta

  # Get response body
  let body = await response.body
  echo body

  # Always close when done
  client.close()

waitFor main()
```

### Server Usage

#### Synchronous Server

```nim
import obiwan

proc handleRequest(request: Request) =
  # Display request info
  echo "URL requested: ", request.url

  # Check for client certificate
  if request.hasCertificate:
    echo "Client certificate: ", request.certificate.commonName

  # Send a response
  request.respond(Success, "text/gemini", """
# Hello from ObiWAN!

This is a sample Gemini page served using the ObiWAN synchronous API.
""")

# Create server with certificate and key
let server = newObiwanServer(
  certFile = "certs/cert.pem",
  keyFile = "certs/privkey.pem"
)

# Start serving on port 1965 (default Gemini port)
server.serve(1965, handleRequest)
```

#### Asynchronous Server

```nim
import obiwan
import asyncdispatch

proc handleRequest(request: AsyncRequest): Future[void] {.async.} =
  # Process the request
  await request.respond(Success, "text/gemini", """
# Hello from ObiWAN!

This is a sample Gemini page served using the ObiWAN asynchronous API.
""")

proc main() {.async.} =
  # Create server with certificate and key
  let server = newAsyncObiwanServer(
    certFile = "certs/cert.pem",
    keyFile = "certs/privkey.pem"
  )

  # Start serving on port 1965 (default Gemini port)
  await server.serve(1965, handleRequest)

waitFor main()
```

## Advanced Usage

### Client Certificates

```nim
# Create client with identity certificate
let client = newObiwanClient(
  certFile = "client-cert.pem",
  keyFile = "client-key.pem"
)

# OR (preferred approach) load certificates after client creation
let client = newObiwanClient()
if client.loadIdentityFile("client-cert.pem", "client-key.pem"):
  echo "Certificate loaded successfully"
  let response = client.request("gemini://example.com/auth")
  # Check if authentication succeeded
  if response.status == Success:
    echo "Authentication successful!"
```

The `loadIdentityFile` approach is recommended because it allows making different
requests with and without client authentication during the same session.

### Server Certificate Verification

```nim
# Check certificate verification in responses
let response = client.request("gemini://geminiprotocol.net/")

if response.hasCertificate:
  echo "Certificate fingerprint: ", response.certificate.fingerprint

  if response.isVerified:
    echo "Certificate is fully verified"
  elif response.isSelfSigned:
    echo "Certificate is self-signed"
  else:
    echo "Certificate verification failed: ", response.verification
```

## API Documentation

### Main Types

- `ObiwanClient` / `AsyncObiwanClient`: Client interfaces
- `ObiwanServer` / `AsyncObiwanServer`: Server interfaces
- `Request` / `AsyncRequest`: Incoming client requests
- `Response` / `AsyncResponse`: Server responses
- `Status`: Gemini status codes (e.g., `Success`, `NotFound`, etc.)

### Certificate Functions

- `commonName`: Get the subject common name from a certificate
- `fingerprint`: Get the SHA-256 fingerprint of a certificate
- `hasCertificate`: Check if a certificate is present
- `isVerified`: Check if a certificate is verified
- `isSelfSigned`: Check if a certificate is self-signed

## Project Structure

```
src/
├── obiwan.nim              # Main package entrypoint
├── obiwan/
│   ├── common.nim          # Shared types and protocols
│   ├── debug.nim           # Debug utilities
│   ├── tls/                # TLS implementation
│   │   ├── mbedtls.nim     # C bindings
│   │   ├── socket.nim      # Base socket
│   │   └── async_socket.nim # Async socket
│   ├── client/
│   │   ├── sync.nim        # Synchronous client
│   │   └── async.nim       # Asynchronous client
│   └── server/
│       ├── sync.nim        # Synchronous server
│       └── async.nim       # Asynchronous server
```

### Running Tests

Use these Nimble tasks to run the test suite:

```bash
# Run all tests
nimble test

# Run all tests in parallel (but out of order)
nimble testparallel

# Run specific test suites
nimble testserver   # Server tests
nimble testclient   # Client tests
nimble testtls      # TLS implementation tests
nimble testurl      # URL parsing tests
```

## Roadmap

- [ ] Gemini text format (text/gemini) parser
- [x] Comprehensive test suite
- [ ] Improved documentation
- [x] Vendored mbedTLS 3.6.2
- [x] TOML configuration file support
- [x] Command-line argument parsing with docopt
- [ ] Complete server implementation with file serving
- [ ] CGI support
- [ ] MIME type detection

## License

All Rights Reserved.

## Acknowledgements

- [Gemini Protocol](https://geminiprotocol.net/) - For creating the Gemini protocol
- [mbedTLS](https://tls.mbed.org/) - For the TLS implementation
- [Nim](https://nim-lang.org/) - For the programming language
