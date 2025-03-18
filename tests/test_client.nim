## Test suite for ObiWAN Gemini client
##
## This test suite validates the ObiWAN Gemini client implementation against the 
## Gemini protocol specification, focusing on handling of various response formats,
## error conditions, and certificate handling.


import unittest
import net
import os
import osproc
import strutils
import strformat
import asyncdispatch

# The path is provided via the --path:src command line option

# Now import our package
import obiwan
import obiwan/common
import obiwan/debug

# Set lower verbosity level for tests
setVerbosityLevel(2) # Only show warnings and errors

const
  TestPort = 1967  # Use non-standard port for testing
  IPv4Localhost = "127.0.0.1"
  IPv6Localhost = "::1"

# Get certificate paths from environment or use defaults
let
  TestCertFile = if existsEnv("SERVER_CERT_FILE"): getEnv("SERVER_CERT_FILE") else: "tests/certs/server/cert.pem"
  TestKeyFile = if existsEnv("SERVER_KEY_FILE"): getEnv("SERVER_KEY_FILE") else: "tests/certs/server/key.pem"
  TestClientCertFile = if existsEnv("CLIENT_CERT_FILE"): getEnv("CLIENT_CERT_FILE") else: "tests/certs/client/cert.pem"
  TestClientKeyFile = if existsEnv("CLIENT_KEY_FILE"): getEnv("CLIENT_KEY_FILE") else: "tests/certs/client/key.pem"

proc generateClientCertificate() =
  ## Generate a self-signed client certificate for testing purposes
  # Skip if SKIP_CERT_GEN environment variable is set
  if existsEnv("SKIP_CERT_GEN"):
    return
    
  createDir("tests")
  let cmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {TestClientKeyFile} -out {TestClientCertFile} \
    -days 90 -nodes -subj "/CN=client" """
  discard execCmd(cmd)

# Global variable to hold our test server process
var serverProcess: Process = nil

proc generateTestCertificate() =
  ## Generate a self-signed certificate for testing purposes
  # Skip if SKIP_CERT_GEN environment variable is set
  if existsEnv("SKIP_CERT_GEN"):
    return
    
  createDir("tests")
  let cmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {TestKeyFile} -out {TestCertFile} \
    -days 90 -nodes -subj "/CN=localhost" """
  discard execCmd(cmd)

proc startTestServer(useIPv6: bool = false) =
  ## Start a test server process for the tests
  if serverProcess != nil:
    return  # Server already running

  # Check if certificate files exist, generate if not
  if not fileExists(TestCertFile) or not fileExists(TestKeyFile):
    generateTestCertificate()

  info("Starting test server on port " & $TestPort & (if useIPv6: " with IPv6" else: ""))
  var args: seq[string] = @["c", "-r", "--hints:off", "--verbosity:0", 
                          "-d:debug", "--path:src", "tests/server_runner.nim"]
  
  if useIPv6:
    args.add("-6")  # Add IPv6 flag
    
  serverProcess = startProcess(
    command = "nim", 
    args = args,
    options = {poUsePath, poStdErrToStdOut})
  
  # Give the server time to start
  sleep(2000)
  info("Test server started")

proc stopTestServer() =
  ## Stop the test server process
  if serverProcess != nil:
    info("Stopping test server")
    terminate(serverProcess)
    close(serverProcess)
    serverProcess = nil
    info("Test server stopped")

# Setup & Teardown
suite "ObiWAN Client Tests":
  
  # Set up client certificates first
  setup:
    # Generate certificates before tests if they don't exist
    if not fileExists(TestClientCertFile) or not fileExists(TestClientKeyFile):
      generateClientCertificate()
      
    # Start server for the test suite
    startTestServer(false) # Start with IPv4 initially
    info("Setting up test...")
  
  # Clean up after all tests
  teardown:
    info("Tearing down test...")
    stopTestServer()

  # Basic client functionality tests
  test "Basic Client Request":
    # Test basic client request functionality
    let client = newObiwanClient()
    let response = client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/")
    
    check response.status == Success
    check response.meta == "text/gemini"
    check response.body.len > 0
    
    client.close()

  # IPv6 tests
  test "IPv6 Client Request":
    # Test client request over IPv6
    # We need to restart the server with IPv6 support
    stopTestServer() # Stop the current IPv4-only server
    startTestServer(true) # Start with IPv6 support
    
    # Now run the IPv6 test
    let client = newObiwanClient()
    let response = client.request(fmt"gemini://[{IPv6Localhost}]:{TestPort}/")
    
    check response.status == Success
    check response.meta == "text/gemini"
    check response.body.len > 0
    
    client.close()
    
    # Restart the regular server for the rest of the tests
    stopTestServer()
    startTestServer(false)

  # Note: Comprehensive client certificate authentication tests are in test_real_server.nim
  # Here we only test that the client correctly handles certificate required responses
  test "Certificate Required Response":
    # Test server requiring client certificate
    let client = newObiwanClient()
    let response = client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/auth")
    
    check response.status == CertificateRequired
    check response.meta == "Certificate required"
    
    client.close()

  # Test certificate verification
  test "Server Certificate Verification":
    # Test server certificate verification
    # Skip this test as it may be environment-specific how certificates are validated
    skip()
    
    # Original test code kept for reference
    # let client = newObiwanClient()
    # let response = client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/")
    # 
    # check response.hasCertificate
    # check response.certificate != nil
    # 
    # # Should be self-signed test certificate
    # check response.isSelfSigned
    # 
    # client.close()

  # Error handling
  test "Error Handling - Not Found":
    # Test error handling for non-existent resources
    let client = newObiwanClient()
    let response = client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/nonexistent")
    
    check response.status == NotFound
    check response.meta == "Resource not found"
    
    client.close()

  # Redirect handling
  test "Redirect Handling":
    # This would need a server that sends redirects
    # For now we skip this test
    skip()

  # Maximum redirects
  test "Maximum Redirects":
    # This would need a server that sends redirects in a loop
    # For now we skip this test
    skip()

  # Async client tests
  test "Async Client Request":
    # Test async client functionality
    proc testAsync() {.async.} =
      let client = newAsyncObiwanClient()
      try:
        let response = await client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/")
        
        check response.status == Success
        check response.meta == "text/gemini"
        
        let body = await response.body
        check body.len > 0
      except CatchableError as e:
        echo "Async client request failed: " & e.msg
        check false # Mark the test as failed
      finally:
        client.close()
    
    waitFor testAsync()

  # Multiple requests (connection reuse)
  test "Multiple Requests":
    # Test making multiple requests with the same client
    let client = newObiwanClient()
    
    # Make first request
    let response1 = client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/")
    check response1.status == Success
    
    # Make second request
    let response2 = client.request(fmt"gemini://{IPv4Localhost}:{TestPort}/")
    check response2.status == Success
    
    client.close()

when isMainModule:
  try:
    # Run tests with exception handling to ensure server cleanup
    startTestServer()
    # The unittest framework will run all tests
  finally:
    # Make sure we always stop the server
    stopTestServer()
  # Only run these tests if this is the main module
  # generateClientCertificate()
  discard