# ObiWAN

A lightweight Gemini protocol client and server library in Nim.

## What is ObiWAN?

ObiWAN is a comprehensive library for building clients and servers that speak the [Gemini protocol](https://gemini://geminiprotocol.net/docs/specification.html), a lightweight alternative to HTTP designed for simplicity and privacy. The library provides both synchronous and asynchronous APIs with a clean, type-safe interface.

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
- mbedTLS 3.6.2 or later

### Installing mbedTLS

On macOS:
```bash
brew install mbedtls
```

On Linux:
```bash
# Debian/Ubuntu
sudo apt install libmbedtls-dev
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

### Installing Nim dependencies

```bash
nimble install nimcrypto
```

### Installing ObiWAN

```bash
nimble install https://github.com/corv89/ObiWAN
```

Or add to your .nimble file:
```
requires "obiwan >= 0.1.0"
```

## Generating Certificates

For testing and development, generate a self-signed certificate:

```bash
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -keyout certs/privkey.pem -out certs/cert.pem -days 365 -nodes
```

## Quick Start

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

# Or load certificates after client creation
if client.loadIdentityFile("client-cert.pem", "client-key.pem"):
  echo "Certificate loaded successfully"
```

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

## Building Examples

Use these Nimble tasks to build the example clients and servers:

```bash
# Build all examples
nimble buildall

# Build individual examples
nimble client       # Sync client
nimble asyncclient  # Async client
nimble server       # Sync server
nimble asyncserver  # Async server
```

### Running the Examples

```bash
# Run synchronous client
./build/client gemini://example.com/

# Run asynchronous client 
./build/async_client gemini://example.com/

# Run synchronous server (IPv4)
./build/server cert.pem key.pem 1965

# Run synchronous server with IPv6 (dual-stack if supported by OS)
./build/server cert.pem key.pem 1965 -6

# Run asynchronous server (IPv4)
./build/async_server cert.pem key.pem 1965

# Run asynchronous server with IPv6 (dual-stack if supported by OS)
./build/async_server cert.pem key.pem 1965 -6
```

## Roadmap

- [ ] Gemini text format (text/gemini) parser
- [ ] Comprehensive test suite
- [ ] Improved documentation
- [ ] Optimized mbedTLS build size
- [ ] Complete server implementation
- [ ] CGI support
- [ ] MIME type support

## License

All Rights Reserved.

## Acknowledgements

- [Gemini Protocol](https://geminiprotocol.net/) - For creating the Gemini protocol
- [mbedTLS](https://tls.mbed.org/) - For the TLS implementation
- [Nim](https://nim-lang.org/) - For the programming language
