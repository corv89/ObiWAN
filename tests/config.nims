# Test configuration for ObiWAN
# This script is executed before running tests to set up the test environment

import os, strformat, strutils

# Get project root directory (parent of tests directory)
let 
  testsDir = thisDir()
  projectDir = parentDir(testsDir)

# Certificate paths - days of validity
const
  CertValidDays = 90  # Set to 90 days for better caching

# Define paths relative to tests directory
let
  # Base directories
  CertDir = testsDir / "certs"
  
  # Server certificate paths
  ServerCertDir = CertDir / "server"
  ServerCertFile = ServerCertDir / "cert.pem"
  ServerKeyFile = ServerCertDir / "key.pem"
  
  # Client certificate paths
  ClientCertDir = CertDir / "client" 
  ClientCertFile = ClientCertDir / "cert.pem"
  ClientKeyFile = ClientCertDir / "key.pem"
  
  # CA certificate paths
  CACertDir = CertDir / "ca"
  CACertFile = CACertDir / "cert.pem"
  CAKeyFile = CACertDir / "key.pem"

# Verbosity level - set to 0 for quiet operation, 1 for normal, 2 for verbose
const VerboseOutput = 0

# Helper to print status messages
proc status(msg: string) =
  if VerboseOutput >= 1:
    echo "✓ ", msg

proc warning(msg: string) =
  # Always show warnings
  echo "! ", msg

proc error(msg: string) =
  # Always show errors
  echo "✗ ", msg

proc debug(msg: string) =
  if VerboseOutput >= 2:
    echo "  ", msg

# Ensure directories exist
proc ensureDirExists(dir: string) =
  if not dirExists(dir):
    mkDir(dir)
    if VerboseOutput >= 2:
      echo "  Created directory: ", dir

ensureDirExists(CertDir)
ensureDirExists(ServerCertDir)
ensureDirExists(ClientCertDir)
# CA directory creation disabled until needed
# ensureDirExists(CACertDir)

# Check if certificate is valid
proc isCertValid(certFile: string): bool =
  if not fileExists(certFile):
    return false
    
  try:
    # Use openssl to check validity
    let cmd = fmt"openssl x509 -checkend 0 -noout -in {certFile}"
    let (output, exitCode) = gorgeEx(cmd)
    return exitCode == 0
  except:
    return false

# Generate server certificate
if not isCertValid(ServerCertFile) or not fileExists(ServerKeyFile):
  status("Generating server certificate...")
  let cmd = fmt"""openssl req -x509 -newkey rsa:4096 -keyout {ServerKeyFile} \
    -out {ServerCertFile} -days {CertValidDays} -nodes -subj "/CN=localhost" """
  let (output, exitCode) = gorgeEx(cmd)
  
  if exitCode == 0:
    status("Server certificate generated")
  else:
    error("Failed to generate server certificate")
    if VerboseOutput >= 1:
      echo output
else:
  status("Using cached server certificate")

# Generate client certificate
if not isCertValid(ClientCertFile) or not fileExists(ClientKeyFile):
  status("Generating client certificate...")
  let cmd = fmt"""openssl req -x509 -newkey rsa:4096 -keyout {ClientKeyFile} \
    -out {ClientCertFile} -days {CertValidDays} -nodes -subj "/CN=client" """
  let (output, exitCode) = gorgeEx(cmd)
  
  if exitCode == 0:
    status("Client certificate generated")
  else:
    error("Failed to generate client certificate")
    if VerboseOutput >= 1:
      echo output
else:
  status("Using cached client certificate")

# Note: We've removed legacy path handling. All tests should be updated
# to use the certificate paths directly from the environment variables.

# Display cert expiration for reference
proc displayCertInfo(certFile: string, certName: string) =
  if VerboseOutput >= 1 and fileExists(certFile):
    let cmd = fmt"openssl x509 -enddate -noout -in {certFile}"
    let (output, exitCode) = gorgeEx(cmd)
    if exitCode == 0:
      let expiryInfo = output.replace("notAfter=", "")
      echo fmt"{certName} expires: {expiryInfo}"
    else:
      warning(fmt"Could not retrieve expiration for {certName}")
  # Don't show warning for missing files - they may be generated later

status("Test certificates are ready")
# Only display certificate info for files that exist if verbose
if VerboseOutput >= 1:
  if fileExists(ServerCertFile):
    displayCertInfo(ServerCertFile, "Server certificate")
  if fileExists(ClientCertFile):
    displayCertInfo(ClientCertFile, "Client certificate")

# Print certificate paths if verbose
if VerboseOutput >= 1:
  echo "==== Certificate Paths ===="
  echo "Server cert: ", ServerCertFile
  echo "Server key:  ", ServerKeyFile
  echo "Client cert: ", ClientCertFile
  echo "Client key:  ", ClientKeyFile

# Export environment variables for test scripts
putEnv("SERVER_CERT_FILE", ServerCertFile)
putEnv("SERVER_KEY_FILE", ServerKeyFile)
putEnv("CLIENT_CERT_FILE", ClientCertFile)
putEnv("CLIENT_KEY_FILE", ClientKeyFile)
putEnv("CA_CERT_FILE", CACertFile)
putEnv("CA_KEY_FILE", CAKeyFile)