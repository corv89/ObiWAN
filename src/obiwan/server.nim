## ObiWAN Gemini Server (Unified)
##
## This module provides a command-line Gemini protocol server
## that supports both synchronous and asynchronous operation (async by default).
## It uses the ObiWAN library and supports configuration via TOML files.
##
## Usage:
##   obiwan-server [options]
##
## Options:
##   -h --help               Show this help screen
##   -v --verbose            Increase verbosity level
##   -c --config=<file>      Use specific config file
##   -p --port=<port>        Port to listen on [default: 1965]
##   -a --address=<addr>     Address to bind to [default: 0.0.0.0]
##   -6 --ipv6               Use IPv6 instead of IPv4
##   --sync                  Use synchronous (blocking) mode
##   -r --reuse-addr         Allow reuse of local addresses [default: true]
##   --reuse-port            Allow multiple bindings to same port
##   --cert=<file>           Server certificate file [default: cert.pem]
##   --key=<file>            Server key file [default: privkey.pem]
##   --docroot=<dir>         Document root directory [default: ./content]
##   --version               Show version information
##
## Configuration is loaded from (in order):
## 1. The specified config file with --config
## 2. ./obiwan.toml (current directory)
## 3. ~/.config/obiwan/config.toml (user config)
## 4. /etc/obiwan/config.toml (system config)
## 5. Default values if no config file is found
## Command line options override values from config files.

import os
import asyncdispatch
import strutils # For parseInt
import "../obiwan"
import "config"
import docopt

const doc = """
ObiWAN Gemini Server

Usage:
  obiwan-server [options]

Options:
  -h --help               Show this help screen
  -v --verbose            Increase verbosity level
  -c --config=<file>      Use specific config file
  -p --port=<port>        Port to listen on [default: 1965]
  -a --address=<addr>     Address to bind to [default: 0.0.0.0]
  -6 --ipv6               Use IPv6 instead of IPv4
  --sync                  Use synchronous (blocking) mode
  -r --reuse-addr         Allow reuse of local addresses [default: true]
  --reuse-port            Allow multiple bindings to same port
  --cert=<file>           Server certificate file [default: cert.pem]
  --key=<file>            Server key file [default: privkey.pem]
  --docroot=<dir>         Document root directory [default: ./content]
  --version               Show version information
"""

const version = "ObiWAN Gemini Server v0.5.0"

# Synchronous request handler
proc handleSyncRequest(request: Request) =
  ## Handles incoming Gemini requests synchronously.
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

# Asynchronous request handler
proc handleAsyncRequest(request: AsyncRequest): Future[void] {.async.} =
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

# Run the server in synchronous mode
proc runSyncServer(config: Config) =
  # Initialize server with TLS certificates
  var server = newObiwanServer(
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
  echo "\nServer starting in synchronous mode..."
  server.serve(config.server.port, handleSyncRequest, effectiveAddress)

# Run the server in asynchronous mode
proc runAsyncServer(config: Config) {.async.} =
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
  echo "\nServer starting in asynchronous mode..."
  await server.serve(config.server.port, handleAsyncRequest, effectiveAddress)

# Main application code
when isMainModule:
  try:
    # Parse command line arguments with docopt
    let args = docopt(doc, version=version)

    # Get configuration file path from arguments
    let configPath = if args["--config"]: $args["--config"] else: ""

    # Load configuration
    var config = loadOrCreateConfig(configPath)

    # Override configuration with command line arguments
    if args["--verbose"]:
      config.log.level = 2  # Increase verbosity

    if args["--port"]:
      try:
        config.server.port = parseInt($args["--port"])
      except ValueError:
        echo "Warning: Invalid port number, using default"

    if args["--address"]:
      config.server.address = $args["--address"]

    # IPv6 setting
    if args["--ipv6"]:
      config.server.useIPv6 = true

    # Reuse flags
    if args["--reuse-addr"]:  # If explicitly set to true
      config.server.reuseAddr = true
    elif args.hasKey("--reuse-addr") and not args["--reuse-addr"].toBool():
      config.server.reuseAddr = false

    if args["--reuse-port"]:
      config.server.reusePort = true

    # Certificate settings
    if args["--cert"]:
      config.server.certFile = $args["--cert"]

    if args["--key"]:
      config.server.keyFile = $args["--key"]

    # Document root
    if args["--docroot"]:
      config.server.docRoot = $args["--docroot"]

    # Initialize logging
    initializeLogging(config)

    # Output startup information
    echo "\nObiWAN Gemini Server"
    echo "===================="

    # Show config path if available, otherwise indicate default config
    if resolveConfigFile(configPath) != "":
      echo "Using configuration from: ", resolveConfigFile(configPath)
    else:
      echo "Using default configuration (no config file found)"

    # Show key server settings
    echo "Server settings:"
    echo "  Mode:       ", if args["--sync"]: "Synchronous" else: "Asynchronous"
    echo "  Address:    ", if config.server.address == "":
                            if config.server.useIPv6: "::" else: "0.0.0.0"
                          else: config.server.address
    echo "  Port:       ", config.server.port
    echo "  Protocol:   ", if config.server.useIPv6: "IPv6" else: "IPv4"
    echo "  Cert file:  ", config.server.certFile
    echo "  Key file:   ", config.server.keyFile
    echo "  Doc root:   ", config.server.docRoot

    # Run in the appropriate mode
    if args["--sync"]:
      runSyncServer(config)
    else:
      waitFor runAsyncServer(config)

  except:
    # Handle any exceptions that occur during server setup or operation
    echo "Error: ", getCurrentExceptionMsg()
