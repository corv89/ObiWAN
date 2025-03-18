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
import strformat # For fmt
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
    echo "  For server: openssl req -x509 -newkey rsa:4096 -nodes -keyout ", serverKeyPath, " -out ", serverCertPath, " -days 365 -subj '/CN=localhost'"
    echo "  For client: openssl req -x509 -newkey rsa:4096 -nodes -keyout ", clientKeyPath, " -out ", clientCertPath, " -days 365 -subj '/CN=client'"
    quit(1)

# Server request handler
proc handleRequest(request: AsyncRequest) {.async.} =
  echo "Request path: ", request.url.path
  if request.url.path == "/auth":
    if not request.hasCertificate():
      # Client didn't provide a certificate, request one
      echo "Client didn't provide a certificate"
      await request.respond(CertificateRequired, "CLIENT CERTIFICATE REQUIRED")
    elif not (request.isVerified() or request.isSelfSigned()):
      # Certificate was provided but isn't valid
      echo "Certificate not valid"
      await request.respond(CertificateRequired, "CERTIFICATE NOT VALID")
    else:
      # Client certificate is valid (either verified or self-signed)
      echo "Client certificate accepted"
      var response = "# Certificate accepted\n\n"
      if request.certificate != nil:
        response.add("## Certificate Information\n\n")
        response.add("Certificate available\n")
        response.add("Verified: " & $request.isVerified & "\n")
        response.add("Self-signed: " & $request.isSelfSigned & "\n\n")
        
        try:
          # We don't have direct access to certificate info struct
          # Just mention that certificate is available
          response.add("Certificate details not accessible through API\n")
        except:
          response.add("Error processing certificate: " & getCurrentExceptionMsg() & "\n")
      
      response.add("Hello authenticated client!")
      await request.respond(Success, "text/gemini", response)
  else:
    # Default welcome page
    await request.respond(Success, "text/gemini", "# Hello world\n\nThis is the ObiWAN test server.\n\nTry visiting /auth to test client certificate authentication.")

# Main application code
proc runServer() {.async.} =
  try:
    # Initialize server with TLS certificates (use more detailed errors)
    echo "Starting server with certificates: ", serverCertPath, ", ", serverKeyPath
    
    # Enable debug mode for more verbose output
    setVerbosityLevel(3)  # Maximum verbosity
    
    var server = newAsyncObiwanServer(
      certFile = serverCertPath, 
      keyFile = serverKeyPath
      # Client certs are requested in the handler, not globally required
    )
    
    echo "Server created successfully. Listening on port 1965..."
    await server.serve(1965, handleRequest)
  except:
    # Handle any exceptions that occur during server setup or operation
    echo "Server error: ", getCurrentExceptionMsg()

# Client implementation to test against our server
proc runClient() {.async.} =
  try:
    echo "Starting client with certificates: ", clientCertPath, ", ", clientKeyPath
    
    # Create client with certificates
    var client = newAsyncObiwanClient(
      certFile = clientCertPath,
      keyFile = clientKeyPath
    )
    
    # First try a normal request (without client cert)
    echo "\n--- Testing normal request (no client cert) ---"
    var response = await client.request("gemini://localhost:1965/")
    echo "Status: ", response.status
    echo "Meta: ", response.meta
    if response.status == Success:
      # Since body is an async method, we need to await it
      let body = await response.body()
      let truncatedBody = if body.len > 100: body[0..99] & "..." else: body
      echo "Body: ", truncatedBody
    
    # Now try with client certificate
    echo "\n--- Testing authenticated request (with client cert) ---"
    response = await client.request("gemini://localhost:1965/auth")
    echo "Status: ", response.status
    echo "Meta: ", response.meta
    if response.status == Success:
      let body = await response.body()
      echo "Body: ", body
    elif response.status == CertificateRequired:
      echo "Certificate required. Retrying with cert..."
      # Reload the client certificate to make sure it's used
      if not client.loadIdentityFile(certFile=clientCertPath, keyFile=clientKeyPath):
        echo "Failed to load client certificate, continuing anyway..."
      response = await client.request("gemini://localhost:1965/auth")
      echo "Status: ", response.status
      echo "Meta: ", response.meta
      if response.status == Success:
        let body = await response.body()
        echo "Body: ", body
      else:
        echo "Still failed after providing certificate"
    else:
      echo "Unexpected status"
  except:
    echo "Client error: ", getCurrentExceptionMsg()

# Run the test
proc main() {.async.} =
  # Ensure certificates exist
  ensureCertificatesExist()
  
  # Start server in background
  asyncCheck runServer()
  echo "Server running in background..."
  
  # Wait a moment for server to start
  await sleepAsync(1000)
  
  # Run client test
  echo "Running client test..."
  await runClient()
  
  # Run an additional test with explicit client cert
  echo "\n--- Testing with explicit client certificate ---"
  var client = newAsyncObiwanClient()
  if client.loadIdentityFile(certFile=clientCertPath, keyFile=clientKeyPath):
    echo "Client certificate loaded successfully"
    var response = await client.request("gemini://localhost:1965/auth")
    echo "Status: ", response.status
    echo "Meta: ", response.meta
    if response.status == Success:
      let body = await response.body()
      echo "Body: ", body
  else:
    echo "Failed to load client certificate"
  
  # Keep server running briefly to allow external testing
  echo "\nServer will remain running for 5 seconds for external testing..."
  echo "You can test with Lagrange using: gemini://localhost:1965/auth"
  await sleepAsync(5000)
  echo "Test complete"

when isMainModule:
  waitFor main()