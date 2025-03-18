## Diagnostic test for client certificate authentication
## 
## This script uses the actual ObiWAN server implementation to test client certificate
## authentication. It creates a standalone Gemini server and client to verify that
## client certificates work correctly with the core ObiWAN implementation.
##
## The issue appears to be that while the actual server implementation works correctly
## with client certificates (including with external clients like Lagrange), the
## test server environment fails with connection reset errors.


import asyncdispatch
import os
import strutils # For parseInt
import unittest # For test framework
import "../src/obiwan"

# Create certificate directories if they don't exist
const
  serverCertDir = "certs/server"
  clientCertDir = "certs/client"

proc ensureDirExists(dir: string) =
  if not dirExists(dir):
    createDir(dir)

ensureDirExists(serverCertDir)
ensureDirExists(clientCertDir)

# Define certificate paths
const
  serverCertPath = serverCertDir & "/cert.pem"
  serverKeyPath = serverCertDir & "/key.pem"
  clientCertPath = clientCertDir & "/cert.pem"
  clientKeyPath = clientCertDir & "/key.pem"

# Check if certificates exist, generate if needed
proc ensureCertificatesExist() =
  var missingFiles: seq[string] = @[]

  for path in [serverCertPath, serverKeyPath, clientCertPath, clientKeyPath]:
    if not fileExists(path):
      missingFiles.add(path)

  if missingFiles.len > 0:
    echo "Missing certificate files: ", missingFiles.join(", ")
    echo "Please generate certificates before running this test:"
    echo "  For server: openssl req -x509 -newkey rsa:4096 -nodes -keyout ",
        serverKeyPath, " -out ", serverCertPath, " -days 365 -subj '/CN=localhost'"
    echo "  For client: openssl req -x509 -newkey rsa:4096 -nodes -keyout ",
        clientKeyPath, " -out ", clientCertPath, " -days 365 -subj '/CN=client'"
    quit(1)

# Server request handler
proc handleRequest(request: AsyncRequest) {.async.} =
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
      response.add("## Certificate Information\n\n")
      if request.certificate != nil:
        response.add("Certificate available\n")
        response.add("Verified: " & $request.isVerified & "\n")
        response.add("Self-signed: " & $request.isSelfSigned & "\n\n")
      response.add("Hello authenticated client!")
      await request.respond(Success, "text/gemini", response)
  else:
    # Default welcome page
    await request.respond(Success, "text/gemini", "# Hello world\n\nThis is the ObiWAN test server.")

# Main application code
# Server is created and started directly in suiteSetup

# Client implementation uses the unittest framework test cases now

# Test suite for client certificate authentication
suite "Client Certificate Authentication Tests":

  # Shared server - initialized once before tests
  var server: AsyncObiwanServer = nil
  var serverInitialized = false

  # Ensure certificates exist
  ensureCertificatesExist()

  # Set minimal verbosity level
  setVerbosityLevel(0)

  # Prepare test environment
  setup:
    # Initialize server only once for all tests
    if not serverInitialized:
      # Create server
      server = newAsyncObiwanServer(
        certFile = serverCertPath,
        keyFile = serverKeyPath
      )

      # Start server in background
      asyncCheck server.serve(1965, handleRequest)

      # Wait for server to initialize
      waitFor sleepAsync(1000)
      serverInitialized = true

  # Clean up after tests
  teardown:
    # Nothing to do - server will stop when test completes
    discard

  # Test basic connection without certificate
  test "Basic Connection Test":
    proc testBasicConnection() {.async.} =
      var client = newAsyncObiwanClient()
      var response = await client.request("gemini://localhost:1965/")
      check response.status == Success
      client.close()

    waitFor testBasicConnection()

  # Test certificate required response
  test "Certificate Required Test":
    proc testCertRequired() {.async.} =
      var client = newAsyncObiwanClient()
      var response = await client.request("gemini://localhost:1965/auth")
      check response.status == CertificateRequired
      client.close()

    waitFor testCertRequired()

  # Test with valid certificate
  test "Valid Certificate Test":
    proc testValidCert() {.async.} =
      var client = newAsyncObiwanClient()
      check client.loadIdentityFile(certFile = clientCertPath,
          keyFile = clientKeyPath)
      var response = await client.request("gemini://localhost:1965/auth")
      check response.status == Success
      client.close()

    waitFor testValidCert()

when isMainModule:
  # Run the test suite
  discard
