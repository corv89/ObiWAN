## Test runner for ObiWAN
##
## This module runs all tests for the ObiWAN library.

import unittest
import os
import osproc
import strformat

# The path is provided via the --path:src command line option

# Import test modules
import test_url_parsing
import test_protocol

# Constants for certificate generation
const
  TestCertFile = "tests/test_cert.pem"
  TestKeyFile = "tests/test_key.pem"
  TestClientCertFile = "tests/client_cert.pem"
  TestClientKeyFile = "tests/client_key.pem"

proc generateTestCertificate() =
  ## Generate a self-signed certificate for testing purposes
  createDir("tests")
  let cmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {TestKeyFile} -out {TestCertFile} \
    -days 1 -nodes -subj "/CN=localhost" """
  discard execCmd(cmd)

proc generateClientCertificate() =
  ## Generate a self-signed client certificate for testing purposes
  createDir("tests")
  let cmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {TestClientKeyFile} -out {TestClientCertFile} \
    -days 1 -nodes -subj "/CN=client" """
  discard execCmd(cmd)

# Import the server and client tests after defining the certificate generation functions
# to avoid circular dependencies
import test_server
import test_client

when isMainModule:
  echo "Running ObiWAN tests..."
  echo "----------------------"
  echo ""

  # Generate certificates for testing
  generateTestCertificate()
  generateClientCertificate()

  # The tests run automatically - no need to call unittest.run()

  echo ""
  echo "Tests complete."
