## Synchronous Gemini Server implementation
## 
## This module provides a synchronous (blocking) Gemini protocol server
## using the ObiWAN library. It demonstrates basic request handling and
## client certificate authentication.
##
## The server responds to two routes:
## - Root path ("/") - A simple welcome message
## - "/auth" - Demonstrates client certificate authentication
##
## Usage:
##   ```
##   ./build/server [cert_file] [key_file] [port] [-6]
##   ```
## Where:
##   - cert_file: Path to server certificate (defaults to "cert.pem")
##   - key_file: Path to server private key (defaults to "privkey.pem")
##   - port: Port to listen on (defaults to 1965)
##   - -6: Optional flag to enable IPv6 support (listens on :: instead of 0.0.0.0)

import os
import strutils # For parseInt
import "../../obiwan"

proc handleRequest(request: Request) =
  ## Handles incoming Gemini requests.
  ##
  ## This callback function processes incoming client requests, implementing
  ## different routes:
  ##
  ## - "/auth": Requires and validates client certificates
  ## - Default: Returns a welcome page
  ##
  ## Parameters:
  ##   request: The Request object containing URL, client info, and response methods
  echo "Request path: ", request.url.path
  if request.url.path == "/auth":
    if not request.hasCertificate():
      # Client didn't provide a certificate, request one
      request.respond(CertificateRequired, "CLIENT CERTIFICATE REQUIRED")
    elif not (request.isVerified() or request.isSelfSigned()):
      # Certificate was provided but isn't valid
      request.respond(CertificateRequired, "CERTIFICATE NOT VALID")
    else:
      # Client certificate is valid (either verified or self-signed)
      var response = "# Certificate accepted\n\n"
      if request.certificate != nil:
        response.add("## Certificate Information\n\n")
        response.add("Certificate available\n")
        response.add("Verified: " & $request.isVerified & "\n")
        response.add("Self-signed: " & $request.isSelfSigned & "\n\n")
      response.add("Hello authenticated client!")
      request.respond(Success, "text/gemini", response)
  else:
    # Default welcome page
    request.respond(Success, "text/gemini", "# Hello world\n\nThis is the ObiWAN Gemini server.\n\nTry visiting /auth to test client certificate authentication.")

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
    echo "Starting server with certificates: ", certFile, ", ", keyFile
    var server = newObiwanServer(certFile = certFile, keyFile = keyFile)

    if useIPv6:
      echo "Server created successfully. Listening on IPv6 port ", port, "..."
      # Use IPv6 any address (::)
      server.serve(port, handleRequest, "::")
    else:
      echo "Server created successfully. Listening on IPv4 port ", port, "..."
      # Default to IPv4 (pass empty string for address parameter)
      server.serve(port, handleRequest)
  except:
    # Handle any exceptions that occur during server setup or operation
    echo "Error: ", getCurrentExceptionMsg()
