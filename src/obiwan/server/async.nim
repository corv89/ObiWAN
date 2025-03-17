## Asynchronous Gemini Server implementation
## 
## This module provides a non-blocking asynchronous Gemini protocol server
## using the ObiWAN library. It demonstrates basic request handling and
## client certificate authentication while utilizing Nim's asyncdispatch
## for efficient concurrency.
##
## The server responds to two routes:
## - Root path ("/") - A simple welcome message
## - "/auth" - Demonstrates client certificate authentication
##
## Usage:
##   ```
##   ./build/async_server [cert_file] [key_file] [port] [-6]
##   ```
## Where:
##   - cert_file: Path to server certificate (defaults to "cert.pem")
##   - key_file: Path to server private key (defaults to "privkey.pem")
##   - port: Port to listen on (defaults to 1965)
##   - -6: Optional flag to enable IPv6 support (listens on :: instead of 0.0.0.0)

import asyncdispatch
import os
import strutils # For parseInt
import "../../obiwan"

proc handleRequest(request: AsyncRequest) {.async.} =
  ## Asynchronously handles incoming Gemini requests.
  ##
  ## This async callback function processes incoming client requests, implementing
  ## different routes without blocking the event loop. It demonstrates:
  ## 
  ## - Asynchronous response handling
  ## - Client certificate validation
  ## - Basic Gemini text responses
  ##
  ## Parameters:
  ##   request: The AsyncRequest object containing URL, client info, and async response methods
  ##
  ## Note:
  ##   All response methods must be awaited since they return Futures
  if request.url.path == "/auth":
    echo request.url.path
    if not request.hasCertificate():
      # Client didn't provide a certificate, request one
      await request.respond(CertificateRequired, "CLIENT CERTIFICATE REQUIRED")
    elif not (request.isVerified() or request.isSelfSigned()):
      # Certificate was provided but isn't valid
      await request.respond(CertificateRequired, "CERTIFICATE NOT VALID")
    else:
      # Client certificate is valid (either verified or self-signed)
      var response = "# Certificate accepted\n\n"
      if request.certificate != nil:
        response.add("## Certificate Information\n\n")
        response.add("Certificate available\n")
        response.add("Verified: " & $request.isVerified & "\n")
        response.add("Self-signed: " & $request.isSelfSigned & "\n\n")
      response.add("Hello authenticated client!")
      await request.respond(Success, "text/gemini", response)
  else:
    # Default welcome page
    await request.respond(Success, "text/gemini", "# Hello world\n\nThis is the ObiWAN Gemini server.\n\nTry visiting /auth to test client certificate authentication.")

# Main application code
when isMainModule:
  try:
    # Parse command line arguments
    var certFile = if paramCount() >= 1: paramStr(1) else: "cert.pem"
    var keyFile = if paramCount() >= 2: paramStr(2) else: "privkey.pem"
    var port = if paramCount() >= 3: parseInt(paramStr(3)) else: 1965
    # Support IPv6 with a -6 flag as the fourth argument
    var useIPv6 = paramCount() >= 4 and paramStr(4) == "-6"
    
    # Initialize server with TLS certificates
    echo "Starting async server with certificates: ", certFile, ", ", keyFile
    var server = newAsyncObiwanServer(certFile = certFile, keyFile = keyFile)
    
    # Start serving requests asynchronously
    # This will run until the Future completes (which is normally never)
    if useIPv6:
      echo "Listening on IPv6 port ", port, "..."
      # Use IPv6 any address (::)
      waitFor server.serve(port, handleRequest, "::")
    else:
      echo "Listening on IPv4 port ", port, "..."
      # Default to IPv4
      waitFor server.serve(port, handleRequest)
  except:
    # Handle any exceptions that occur during server setup or operation
    echo "Error: ", getCurrentExceptionMsg()
