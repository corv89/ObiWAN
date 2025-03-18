## Test suite for TLS functionality in ObiWAN
##
## This test suite validates ObiWAN's TLS implementation, focusing on certificate
## handling, verification, and TLS connection properties.

import unittest
import os
import osproc
import strutils
import strformat
import asyncdispatch

# The path is provided via the --path:src command line option

# Now import our package
import obiwan
import obiwan/tls/mbedtls
import obiwan/tls/socket
import obiwan/tls/async_socket
import obiwan/common
import obiwan/debug

const
  TestPort = 1968  # Use non-standard port for testing
  IPv4Localhost = "127.0.0.1"
  TestCertFile = "tests/test_cert.pem"
  TestKeyFile = "tests/test_key.pem"
  TestClientCertFile = "tests/client_cert.pem"
  TestClientKeyFile = "tests/client_key.pem"
  TestCACertFile = "tests/ca_cert.pem"
  TestCAKeyFile = "tests/ca_key.pem"

proc generateTestCertificates() =
  ## Generate certificates for testing
  createDir("tests")
  
  # Generate CA certificate
  let caCmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {TestCAKeyFile} -out {TestCACertFile} \
    -days 1 -nodes -subj "/CN=TestCA" """
  discard execCmd(caCmd)
  
  # Generate server certificate
  let serverCmd = &"""openssl req -newkey rsa:4096 -keyout {TestKeyFile} -out tests/server.csr \
    -nodes -subj "/CN=localhost" && \
    openssl x509 -req -in tests/server.csr -CA {TestCACertFile} -CAkey {TestCAKeyFile} \
    -CAcreateserial -out {TestCertFile} -days 1"""
  discard execCmd(serverCmd)
  
  # Generate client certificate
  let clientCmd = &"""openssl req -newkey rsa:4096 -keyout {TestClientKeyFile} -out tests/client.csr \
    -nodes -subj "/CN=client" && \
    openssl x509 -req -in tests/client.csr -CA {TestCACertFile} -CAkey {TestCAKeyFile} \
    -CAcreateserial -out {TestClientCertFile} -days 1"""
  discard execCmd(clientCmd)

proc testSSLContext(testName: string, useCACert: bool = false): bool =
  ## Test creating an SSL context with various options
  try:
    var context = newMbedtlsSslContext()
    
    # Configure context
    if useCACert:
      discard context.loadCertificateAuthority(TestCACertFile)
    
    # Load keys and certificates
    discard context.loadIdentityFile(TestCertFile, TestKeyFile)
    
    result = true
  except:
    echo "Failed: ", testName
    echo getCurrentExceptionMsg()
    result = false

suite "TLS Functionality Tests":
  
  generateTestCertificates()
  
  setup:
    echo "Setting up test..."
  
  teardown:
    echo "Tearing down test..."

  # Basic TLS context creation
  test "Create SSL Context":
    check testSSLContext("Create SSL Context")
  
  # TLS context with CA certificate
  test "SSL Context with CA Certificate":
    check testSSLContext("SSL Context with CA Certificate", true)
  
  # Certificate loading
  test "Certificate Loading":
    var context = newMbedtlsSslContext()
    
    # Load identity
    let loadIdentity = context.loadIdentityFile(TestCertFile, TestKeyFile)
    check loadIdentity
    
    # Load CA certificate
    let loadCA = context.loadCertificateAuthority(TestCACertFile)
    check loadCA
  
  # Certificate properties
  test "Certificate Properties":
    var context = newMbedtlsSslContext()
    discard context.loadIdentityFile(TestCertFile, TestKeyFile)
    
    # Get certificate and check properties
    let cert = context.getCertificate()
    check cert != nil
    
    # Check certificate common name
    let cn = cert.commonName
    check cn == "localhost"
    
    # Check fingerprint
    let fingerprint = cert.fingerprint
    check fingerprint.len > 0
  
  # Certificate verification
  test "Certificate Verification":
    # This is a basic test of the verification functionality
    # A complete test would need a more complex setup
    var context = newMbedtlsSslContext()
    
    # Load CA cert for verification
    discard context.loadCertificateAuthority(TestCACertFile)
    
    # Load server cert that should be verified by the CA
    discard context.loadIdentityFile(TestCertFile, TestKeyFile)
    
    # Set verification mode
    context.setVerifyMode(VerifyPeer)
    
    # Actual verification happens during handshake
    # which we can't easily test in isolation
  
  # TLS version verification  
  test "TLS Version Support":
    var context = newMbedtlsSslContext()
    
    # mbedTLS defaults to TLS 1.2+ as minimum version
    # Just verify we can set the minimum version
    
    # Try to set minimum version to TLS 1.2 (should succeed)
    let setMinTLS12 = context.setMinVersion(TLS_V12)
    check setMinTLS12
    
    # Recommended version should be TLS 1.3
    let setMinTLS13 = context.setMinVersion(TLS_V13)
    check setMinTLS13
    
    # Verify we're not allowing old versions
    var hasOldVersions = false
    try:
      let setMinTLS10 = context.setMinVersion(TLS_V10)
      hasOldVersions = setMinTLS10
    except:
      # Expected to fail or reject old versions
      hasOldVersions = false
    
    check not hasOldVersions
  
  # Self-signed certificate detection
  test "Self-signed Certificate Detection":
    # Create a self-signed certificate context
    var selfSignedContext = newMbedtlsSslContext()
    
    # Generate a self-signed cert for this test
    let selfSignedCert = "tests/self_signed.pem"
    let selfSignedKey = "tests/self_signed_key.pem"
    
    let cmd = &"""openssl req -x509 -newkey rsa:4096 -keyout {selfSignedKey} -out {selfSignedCert} \
      -days 1 -nodes -subj "/CN=self-signed" """
    discard execCmd(cmd)
    
    # Load the self-signed certificate
    discard selfSignedContext.loadIdentityFile(selfSignedCert, selfSignedKey)
    
    # Get the certificate
    let cert = selfSignedContext.getCertificate()
    check cert != nil
    
    # Check the common name
    let cn = cert.commonName
    check cn == "self-signed"
    
    # Remove the temporary files
    removeFile(selfSignedCert)
    removeFile(selfSignedKey)
  
  # TLS socket creation
  test "TLS Socket Creation":
    var context = newMbedtlsSslContext()
    discard context.loadIdentityFile(TestCertFile, TestKeyFile)
    
    # Create a socket
    var socket = newTlsSocket(context)
    check socket != nil
    
    # No actual connection test here, just creation
  
  # Async TLS socket creation
  test "Async TLS Socket Creation":
    var context = newMbedtlsSslContext()
    discard context.loadIdentityFile(TestCertFile, TestKeyFile)
    
    # Create an async socket
    var socket = newAsyncTlsSocket(context)
    check socket != nil
    
    # No actual connection test here, just creation

when isMainModule:
  # Run tests only if this is the main module
  # No need to call run - unittest framework does it automatically