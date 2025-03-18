## Test server runner for ObiWAN
##
## This module runs a test server for the test suite. It is launched as a separate
## process by the test suite. It implements all the test cases needed for protocol
## compliance testing.

# The path is provided via the --path:src command line option

# Import package modules
import obiwan
import obiwan/common
import obiwan/server/sync
import obiwan/debug
import obiwan/tls/socket as tlsSocket

import strutils
import uri
import os
import strformat
import net
import osproc

const
  TestPort = 1967     # Use non-standard port for testing
  MaxUrlLength = 1024 # Maximum URL length per Gemini spec

# Get certificate paths from environment or use defaults
let
  TestCertFile = if existsEnv("SERVER_CERT_FILE"): getEnv(
      "SERVER_CERT_FILE") else: "tests/certs/server/cert.pem"
  TestKeyFile = if existsEnv("SERVER_KEY_FILE"): getEnv(
      "SERVER_KEY_FILE") else: "tests/certs/server/key.pem"

proc handleRequest(request: Request) =
  ## Handle incoming Gemini requests, implementing all test cases
  ## needed for the protocol compliance tests.

  info("Received request: " & $request.url)

  # Get URL components
  let url = request.url
  let scheme = url.scheme
  let hostname = url.hostname
  let port = url.port
  let path = url.path
  let query = url.query

  # Basic validation helpers
  let isGeminiScheme = scheme == "gemini"
  let isLocalhost = hostname == "localhost" or hostname == "127.0.0.1" or
      hostname == "::1"
  let isTestPort = port == $TestPort or port == "" # Empty means default port
  let rawUrl = $url

  # Safely check for client certificate
  try:
    if request.hasCertificate:
      info("Client provided certificate")

      try:
        # Cast to correct type for X509Certificate from socket module
        let certPtr = cast[tlsSocket.X509Certificate](request.certificate)
        info("Certificate object obtained")

        try:
          var cn = certPtr.commonName()

          # Log certificate details
          debug("Client certificate details:", 3)
          debug("  Certificate CN: " & cn, 3)
          debug("  Self-signed: " & $request.isSelfSigned, 3)
          debug("  Verified: " & $request.isVerified, 3)
          debug("  Verification status: " & $request.verification, 3)

          try:
            debug("  Certificate fingerprint: " & certPtr.fingerprint(), 3)
          except:
            debug("  Error getting fingerprint: " & getCurrentExceptionMsg(), 3)

          # Print detailed certificate info at highest verbosity
          try:
            withDebug:
              debug("Full certificate details:\n" & $certPtr, 4)
          except:
            debug("  Error getting full certificate details: " &
                getCurrentExceptionMsg(), 4)

        except:
          debug("Error processing certificate details: " &
              getCurrentExceptionMsg(), 2)
      except:
        debug("Error casting certificate object: " & getCurrentExceptionMsg(), 2)
    else:
      debug("No client certificate provided", 3)
  except:
    debug("Error checking for client certificate: " & getCurrentExceptionMsg(), 2)

  # Start with protocol validation tests

  # 1. Check scheme
  if not isGeminiScheme:
    # Reject non-Gemini schemes
    request.respond(ProxyRefused, "Only gemini:// URLs are supported")
    return

  # 2. Check hostname/proxy attempts
  if not isLocalhost:
    # Reject proxy attempts to other hosts
    request.respond(ProxyRefused, "This server doesn't support proxying to other hosts")
    return

  # 3. Check port
  if not isTestPort and port != "1965":
    # Reject proxy attempts to other ports
    request.respond(ProxyRefused, "This server doesn't support connecting to other ports")
    return

  # 4. Check URL length
  if rawUrl.len > MaxUrlLength:
    # Reject overly long URLs
    request.respond(MalformedRequest, "URL exceeds maximum length of 1024 bytes")
    return

  # Check for non-URL request format
  if scheme == "" and path.len > 0:
    # Invalid URL format without scheme
    request.respond(MalformedRequest, "Missing scheme - URL must start with gemini://")
    return

  # 5. Path traversal protection
  if ".." in path:
    # Block path traversal attempts
    request.respond(Error, "Path traversal attempts are not allowed")
    return

  # Now handle specific test paths

  # Root path
  if path == "/" or path == "":
    # Default response
    request.respond(Success, "text/gemini", """# Hello world

This is the ObiWAN Gemini test server.

Try visiting /auth to test client certificate authentication.""")
    return

  # Certificate auth test
  elif path == "/auth":
    # Client certificate required
    if not request.hasCertificate:
      debug("No client certificate provided, requesting one", 2)
      request.respond(CertificateRequired, "Certificate required")
    else:
      # Client provided a certificate, accept it for testing
      debug("Client certificate authentication successful", 2)

      # Get certificate details for the response
      let certPtr = cast[tlsSocket.X509Certificate](request.certificate)
      let cn = certPtr.commonName()

      request.respond(Success, "text/gemini",
          """
# Authenticated

You have successfully authenticated with a client certificate.

## Certificate Information

Certificate CN: """ & cn & """
Self-signed: """ & $request.isSelfSigned &
          """
Verified: """ & $request.isVerified & """
Verification status: """ & $request.verification &
          """
Fingerprint: """ & certPtr.fingerprint() & """
""")
    return

  # TLS version info
  elif path == "/tls-info":
    # Return information about the TLS connection
    request.respond(Success, "text/gemini", """
# TLS Connection Information

TLS Version: TLS 1.3 (assumed)
""")
    return

  # Redirect test
  elif path == "/redirect":
    # Test redirect handling
    let target = if query.len > 0: query else: "/"
    request.respond(Redirect, fmt"gemini://localhost:{TestPort}/{target}")
    return

  # Redirect loop test
  elif path == "/redirect-loop":
    # Test redirect loop handling
    let count = if query.len > 0: parseInt(query) else: 0
    if count < 10:
      request.respond(Redirect, fmt"gemini://localhost:{TestPort}/redirect-loop?{count+1}")
    else:
      request.respond(Success, "text/gemini", "# Redirect loop ended\n\nRedirected 10 times")
    return

  # Input test
  elif path == "/input":
    # Test input handling
    request.respond(Input, "Enter your query")
    return

  # Sensitive input test
  elif path == "/sensitive-input":
    # Test sensitive input handling
    request.respond(SensitiveInput, "Enter your password")
    return

  # Error statuses
  elif path == "/server-error":
    request.respond(TempError, "Temporary server error")
    return

  elif path == "/not-available":
    request.respond(ServerUnavailable, "Server temporarily unavailable")
    return

  # By default, return not found
  else:
    request.respond(NotFound, "Resource not found")
    return

when isMainModule:
  # Set lower verbosity level for tests
  setVerbosityLevel(3) # Show info, warnings, and errors

  try:
    # Ensure certificates exist before starting the server
    # Skip certificate generation if SKIP_CERT_GEN is set
    if (not fileExists(TestCertFile) or not fileExists(TestKeyFile)) and
        not existsEnv("SKIP_CERT_GEN"):
      info("Generating test certificate and key")
      let cmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {TestKeyFile} -out {TestCertFile} \
        -days 90 -nodes -subj "/CN=localhost" """
      discard execCmd(cmd)
      sleep(500) # Give filesystem time to update
    
    # Make sure the certificates were generated successfully
    if not fileExists(TestCertFile) or not fileExists(TestKeyFile):
      echo "Failed to create certificate files"
      quit(1)

    # Create server with test certificate and key
    info("Creating server with certificates: " & TestCertFile & ", " & TestKeyFile)

    # Use the actual server implementation from obiwan/server/sync.nim
    var server = newObiwanServer(
      certFile = TestCertFile,
      keyFile = TestKeyFile
    )

    # Get command line arguments
    var useIPv6 = false
    for i in 1..paramCount():
      if paramStr(i) == "-6":
        useIPv6 = true
        break

    # TLS version is configured by mbedTLS defaults (typically TLS 1.2+)

    # Start serving
    info("Starting test server on port " & $TestPort & (
        if useIPv6: " with IPv6" else: " (IPv4 only)"))

    if useIPv6:
      # Use IPv6 dual-stack mode (accepts both IPv4 and IPv6 connections)
      server.serve(TestPort, handleRequest, "::")
    else:
      # IPv4 only mode
      server.serve(TestPort, handleRequest)
  except:
    # Handle any exceptions during server startup
    echo "Error starting server: ", getCurrentExceptionMsg()
    quit(1)
