# Package

version       = "0.3.0"
author        = "Corvin Wimmer"
description   = "A lightweight Gemini protocol client and server library in Nim."
license       = "All Rights Reserved"
srcDir        = "src"

# Dependencies

requires "nim >= 2.2.2"
requires "nimcrypto >= 0.6.2"
requires "genny >= 0.1.0"

task client, "Build sync client":
  exec "nim c -o:build/client src/obiwan/client/sync.nim"

task asyncclient, "Build async client":
  exec "nim c -o:build/async_client src/obiwan/client/async.nim"

task server, "Build sync server":
  exec "nim c -o:build/server src/obiwan/server/sync.nim"

task asyncserver, "Build async server":
  exec "nim c -o:build/async_server src/obiwan/server/async.nim"

task buildall, "Build all":
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"

  # Now build the ObiWAN components
  exec "nim c -o:build/client src/obiwan/client/sync.nim"
  exec "nim c -o:build/async_client src/obiwan/client/async.nim"
  exec "nim c -o:build/server src/obiwan/server/sync.nim"
  exec "nim c -o:build/async_server src/obiwan/server/async.nim"

task test, "Run all tests in sequence":
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"

  # Ensure certificates are properly set up
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"

  echo "\nCompiling all tests in parallel..."
  # Create build directory if it doesn't exist
  exec "mkdir -p " & thisDir() & "/build"

  # First, compile all tests in parallel with streaming output
  exec """
    cd """ & thisDir() & """ &&
    printf "\n===== Compiling All Tests in Parallel =====\n" &&
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_url_parsing tests/test_url_parsing.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_protocol tests/test_protocol.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_server tests/test_server.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_client tests/test_client.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_real_server tests/test_real_server.nim &

    # Wait for all compilations to complete
    wait
  """

  # Now run each test in sequence
  echo "\nRunning all tests sequentially..."

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_url_parsing"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_protocol"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_server"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_client"

  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 ./build/test_real_server"

  # Note: TLS tests have indentation issues that need fixing
  # echo "\nRunning TLS tests..."
  # exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --hints:off --path:src tests/test_tls.nim"

  # Note: IPv6 tests are experimental and may need more work
  # echo "\nRunning IPv6 tests..."
  # exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --hints:off --path:src tests/ipv6_test.nim"

task testparallel, "Run all tests in parallel":
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"

  # Ensure certificates are properly set up
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"

  # Create build directory if it doesn't exist
  exec "mkdir -p " & thisDir() & "/build"

  # First compile all tests in parallel
  echo "\nCompiling all tests in parallel..."
  exec """
    cd """ & thisDir() & """ &&
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_url_parsing tests/test_url_parsing.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_protocol tests/test_protocol.nim &
    nim c --parallelBuild:0 -d:release --hints:off --path:src -o:build/test_server tests/test_server.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_client tests/test_client.nim &
    nim c --parallelBuild:0 -d:release -w:off --hints:off --path:src -o:build/test_real_server tests/test_real_server.nim &

    # Wait for all compilations to complete
    wait
  """

  # Run all tests at once for maximum speed
  # Note output will be out of order
  echo "\nRunning all tests in parallel for maximum speed...\n"
  exec """
    cd """ & thisDir() & """ &&
    SKIP_CERT_GEN=1 ./build/test_url_parsing &
    SKIP_CERT_GEN=1 ./build/test_protocol &
    SKIP_CERT_GEN=1 ./build/test_server &
    SKIP_CERT_GEN=1 ./build/test_client &
    SKIP_CERT_GEN=1 ./build/test_real_server &
    wait
  """

task testserver, "Run server tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_server.nim"

task testclient, "Run client tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  # Pass environment variables to prevent regeneration of certificates
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release -w:off --hints:off --path:src tests/test_client.nim"

task testcertauth, "Run client certificate auth tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release -w:off --hints:off --path:src tests/test_real_server.nim"

task testtls, "Run TLS tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_tls.nim"

task testurl, "Run URL parsing tests":
  exec "cd " & thisDir() & " && nim c -r --parallelBuild:0 -d:release --hints:off --path:src tests/test_url_parsing.nim"

task testprotocol, "Run protocol compliance tests":
  echo "Ensuring test certificates are available..."
  exec "cd " & thisDir() & "/tests && nim --hints:off e config.nims"
  exec "cd " & thisDir() & " && SKIP_CERT_GEN=1 nim c --parallelBuild:0 -d:release -r --hints:off --path:src tests/test_protocol.nim"

task buildmbedtls, "Build the vendored mbedTLS library":
  echo "Building vendored mbedTLS 3.6.2..."
  exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"
  echo "mbedTLS build complete."

task bindings, "Generate C bindings for ObiWAN":
  # Create necessary directories
  exec "mkdir -p " & thisDir() & "/bindings/generated"
  
  # First build mbedTLS if not already built
  let mbedtlsLib = thisDir() & "/vendor/mbedtls/library/libmbedtls.a"
  if not fileExists(mbedtlsLib):
    echo "Building vendored mbedTLS first..."
    exec "cd " & thisDir() & "/vendor/mbedtls && make -j lib"
  
  # Build the shared library with wrapper functions
  echo "Building shared library..."
  exec "nim c --app:lib --threads:on --tlsEmulation:off -d:release -o:build/libobiwan.so bindings/wrapper.nim"
  
  # Create C header for the wrapper
  echo "Generating C header..."
  let headerContent = """
/* ObiWAN C API - Generated header */
#ifndef OBIWAN_H
#define OBIWAN_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handles */
typedef void* ObiwanClientHandle;
typedef void* ObiwanServerHandle;

/* Status codes */
enum ObiwanStatus {
    INPUT = 10,
    SENSITIVE_INPUT = 11,
    SUCCESS = 20,
    TEMP_REDIRECT = 30,
    REDIRECT = 31,
    TEMP_ERROR = 40,
    SERVER_UNAVAILABLE = 41,
    CGI_ERROR = 42,
    PROXY_ERROR = 43,
    SLOWDOWN = 44,
    ERROR = 50,
    NOT_FOUND = 51,
    GONE = 52,
    PROXY_REFUSED = 53,
    MALFORMED_REQUEST = 59,
    CERTIFICATE_REQUIRED = 60,
    CERTIFICATE_UNAUTHORIZED = 61,
    CERTIFICATE_NOT_VALID = 62
};

/* Response data structure */
typedef struct {
    int status;
    const char* meta;
    const char* body;
    bool hasBody;
} ObiwanResponseData;

/* Initialize the ObiWAN library */
void initObiwan(void);

/* Client API */
ObiwanClientHandle createClient(int maxRedirects, const char* certFile, const char* keyFile);
void destroyClient(ObiwanClientHandle client);
int requestUrl(ObiwanClientHandle client, const char* url, ObiwanResponseData* response);

/* Server API */
ObiwanServerHandle createServer(bool reuseAddr, bool reusePort, const char* certFile, const char* keyFile, const char* sessionId);
void destroyServer(ObiwanServerHandle server);

#ifdef __cplusplus
}
#endif

#endif /* OBIWAN_H */
"""
  
  writeFile(thisDir() & "/bindings/generated/obiwan.h", headerContent)
  
  # Create a Python wrapper
  echo "Generating Python wrapper..."
  let pythonContent = """#!/usr/bin/env python3
\"\"\"ObiWAN Python Bindings - A Gemini protocol client and server library\"\"\"

import ctypes
import os
import platform
from ctypes import c_int, c_char_p, c_bool, c_void_p, Structure, POINTER, byref

# Determine library name based on platform
if platform.system() == "Windows":
    _lib_name = "obiwan.dll"
elif platform.system() == "Darwin":
    _lib_name = "libobiwan.dylib"
else:
    _lib_name = "libobiwan.so"

# Find library path
_lib_path = os.path.join(os.path.dirname(__file__), "..", "..", "build", _lib_name)
if not os.path.exists(_lib_path):
    _lib_path = os.path.join(os.path.dirname(__file__), "..", "..", _lib_name)

# Load the library
_lib = ctypes.CDLL(_lib_path)

# Define the response data structure
class ObiwanResponseData(Structure):
    _fields_ = [
        ("status", c_int),
        ("meta", c_char_p),
        ("body", c_char_p),
        ("hasBody", c_bool)
    ]

# Status codes
class Status:
    INPUT = 10
    SENSITIVE_INPUT = 11
    SUCCESS = 20
    TEMP_REDIRECT = 30
    REDIRECT = 31
    TEMP_ERROR = 40
    SERVER_UNAVAILABLE = 41
    CGI_ERROR = 42
    PROXY_ERROR = 43
    SLOWDOWN = 44
    ERROR = 50
    NOT_FOUND = 51
    GONE = 52
    PROXY_REFUSED = 53
    MALFORMED_REQUEST = 59
    CERTIFICATE_REQUIRED = 60
    CERTIFICATE_UNAUTHORIZED = 61
    CERTIFICATE_NOT_VALID = 62

# Set function prototypes
_lib.initObiwan.argtypes = []
_lib.initObiwan.restype = None

_lib.createClient.argtypes = [c_int, c_char_p, c_char_p]
_lib.createClient.restype = c_void_p

_lib.destroyClient.argtypes = [c_void_p]
_lib.destroyClient.restype = None

_lib.requestUrl.argtypes = [c_void_p, c_char_p, POINTER(ObiwanResponseData)]
_lib.requestUrl.restype = c_int

_lib.createServer.argtypes = [c_bool, c_bool, c_char_p, c_char_p, c_char_p]
_lib.createServer.restype = c_void_p

_lib.destroyServer.argtypes = [c_void_p]
_lib.destroyServer.restype = None

# Initialize library
_lib.initObiwan()

class Response:
    \"\"\"Represents a response from a Gemini server\"\"\"
    
    def __init__(self, status, meta, body=None):
        self.status = status
        self.meta = meta
        self._body = body
    
    @property
    def body(self):
        return self._body
    
    def __str__(self):
        if self._body:
            return f"Status: {self.status}, Meta: {self.meta}, Body: {len(self._body)} bytes"
        else:
            return f"Status: {self.status}, Meta: {self.meta}"

class ObiwanClient:
    \"\"\"Gemini protocol client\"\"\"
    
    def __init__(self, max_redirects=5, cert_file="", key_file=""):
        \"\"\"Create a new Gemini client\"\"\"
        self._handle = _lib.createClient(
            max_redirects,
            cert_file.encode('utf-8') if cert_file else None,
            key_file.encode('utf-8') if key_file else None
        )
        if not self._handle:
            raise RuntimeError("Failed to create ObiwanClient")
    
    def __del__(self):
        self.close()
    
    def close(self):
        \"\"\"Close the client and free resources\"\"\"
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyClient(self._handle)
            self._handle = None
    
    def request(self, url):
        \"\"\"Make a request to a Gemini server\"\"\"
        if not self._handle:
            raise RuntimeError("Client is closed")
        
        response_data = ObiwanResponseData()
        result = _lib.requestUrl(self._handle, url.encode('utf-8'), byref(response_data))
        
        if result != 0:
            raise RuntimeError("Request failed")
        
        body = None
        if response_data.hasBody and response_data.body:
            body = response_data.body.decode('utf-8')
        
        meta = response_data.meta.decode('utf-8') if response_data.meta else ""
        
        return Response(response_data.status, meta, body)

class ObiwanServer:
    \"\"\"Gemini protocol server\"\"\"
    
    def __init__(self, reuse_addr=True, reuse_port=False, cert_file="", key_file="", session_id=""):
        \"\"\"Create a new Gemini server\"\"\"
        self._handle = _lib.createServer(
            reuse_addr, 
            reuse_port,
            cert_file.encode('utf-8') if cert_file else None, 
            key_file.encode('utf-8') if key_file else None,
            session_id.encode('utf-8') if session_id else None
        )
        if not self._handle:
            raise RuntimeError("Failed to create ObiwanServer")
    
    def __del__(self):
        self.close()
    
    def close(self):
        \"\"\"Close the server and free resources\"\"\"
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyServer(self._handle)
            self._handle = None
"""
  
  writeFile(thisDir() & "/bindings/generated/python/obiwan.py", pythonContent)
  
  echo "Bindings generation complete. Files generated in bindings/generated/"

task testhelp, "Show information about test tasks":
  echo """
ObiWAN Testing Options
======================

This project offers multiple ways to run tests with different trade-offs:

1. nimble test
   - Compiles all tests in parallel, then runs them sequentially
   - Output is clean and organized by test
   - Good balance between speed and readability
   - Default option for most development work

3. nimble testparallel
   - Maximum speed: compiles and runs all tests in parallel
   - Output is interleaved but preserves colors
   - Fastest option but output may be mixed

Individual test tasks:
- nimble testurl      - Run only URL parsing tests
- nimble testprotocol - Run only protocol tests
- nimble testserver   - Run only server tests
- nimble testclient   - Run only client tests
- nimble testcertauth - Run only client certificate tests
- nimble testtls      - Run only TLS tests (currently disabled)

All tests use parallel compilation with --parallelBuild:0 flag to utilize all CPU cores.
"""
