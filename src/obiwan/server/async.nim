## Asynchronous Gemini Server implementation
## 
## This module provides an asynchronous (non-blocking) Gemini protocol server
## using the ObiWAN library. It supports configuration via TOML files
## for easier setup and maintenance.
##
## Usage:
##   ```
##   ./build/async_server [config_file] [-6]
##   ```
## Where:
##   - config_file: Optional path to TOML configuration file (default: searches for obiwan.toml)
##   - -6: Optional flag to force IPv6 mode regardless of config file
##
## Configuration is loaded from:
## 1. The specified config file or
## 2. ./obiwan.toml (current directory) or
## 3. ~/.config/obiwan/config.toml (user config) or
## 4. /etc/obiwan/config.toml (system config)
## 5. Default values if no config file is found

import os
import asyncdispatch
import "../../obiwan"
import "../config"

proc handleRequest(request: AsyncRequest): Future[void] {.async.} =
  ## Handles incoming Gemini requests asynchronously.
  ##
  ## This callback function processes incoming client requests, implementing
  ## different routes:
  ##
  ## - "/auth": Requires and validates client certificates
  ## - Default: Returns a welcome page
  ##
  ## Parameters:
  ##   request: The AsyncRequest object containing URL, client info, and response methods
  echo "Request path: ", request.url.path
  if request.url.path == "/auth":
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
    await request.respond(Success, "text/gemini", "# Hello world\n\nThis is the ObiWAN Async Gemini server.\n\nTry visiting /auth to test client certificate authentication.")

# Main application code
when isMainModule:
  # Parse command line arguments
  var configPath = if paramCount() >= 1 and not (paramStr(1) == "-6"): paramStr(1) else: ""
  var forceIPv6 = paramCount() >= 1 and paramStr(1) == "-6" or
                  paramCount() >= 2 and paramStr(2) == "-6"
  
  try:
    # Load configuration
    var config = loadOrCreateConfig(configPath)
    
    # Initialize logging
    initializeLogging(config)
    
    # Override IPv6 setting if -6 flag is provided
    if forceIPv6:
      config.server.useIPv6 = true
    
    # Output startup information
    echo "\nObiWAN Async Gemini Server"
    echo "========================="
    
    # Show config path if available, otherwise indicate default config
    if resolveConfigFile(configPath) != "":
      echo "Using configuration from: ", resolveConfigFile(configPath)
    else:
      echo "Using default configuration (no config file found)"
    
    # Show key server settings
    echo "Server settings:"
    echo "  Address:    ", if config.server.address == "": 
                            if config.server.useIPv6: "::" else: "0.0.0.0" 
                          else: config.server.address
    echo "  Port:       ", config.server.port
    echo "  Protocol:   ", if config.server.useIPv6: "IPv6" else: "IPv4"
    echo "  Cert file:  ", config.server.certFile
    echo "  Key file:   ", config.server.keyFile
    echo "  Doc root:   ", config.server.docRoot
    
    # Initialize server with TLS certificates
    var server = newAsyncObiwanServer(
      reuseAddr = config.server.reuseAddr,
      reusePort = config.server.reusePort,
      certFile = config.server.certFile,
      keyFile = config.server.keyFile,
      sessionId = config.server.sessionId
    )
    
    # Get the effective address
    let effectiveAddress = if config.server.address == "": 
                            if config.server.useIPv6: "::" else: "" 
                           else: config.server.address
    
    # Start the server
    echo "\nServer starting..."
    waitFor server.serve(config.server.port, handleRequest, effectiveAddress)
    
  except:
    # Handle any exceptions that occur during server setup or operation
    echo "Error: ", getCurrentExceptionMsg()