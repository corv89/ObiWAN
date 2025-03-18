#!/usr/bin/env python3
"""ObiWAN Python Bindings - A Gemini protocol client and server library"""

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
        ("hasBody", c_bool),
        ("hasCertificate", c_bool),
        ("isVerified", c_bool),
        ("isSelfSigned", c_bool)
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

# Set function prototypes - core functions
_lib.initObiwan.argtypes = []
_lib.initObiwan.restype = None

# Error handling functions
_lib.hasError.argtypes = []
_lib.hasError.restype = c_bool

_lib.getLastError.argtypes = []
_lib.getLastError.restype = c_char_p

# Client functions
_lib.createClient.argtypes = [c_int, c_char_p, c_char_p]
_lib.createClient.restype = c_void_p

_lib.destroyClient.argtypes = [c_void_p]
_lib.destroyClient.restype = None

# Response functions
_lib.requestUrl.argtypes = [c_void_p, c_char_p]
_lib.requestUrl.restype = c_void_p

_lib.destroyResponse.argtypes = [c_void_p]
_lib.destroyResponse.restype = None

_lib.getResponseStatus.argtypes = [c_void_p]
_lib.getResponseStatus.restype = c_int

_lib.getResponseMeta.argtypes = [c_void_p]
_lib.getResponseMeta.restype = c_char_p

_lib.getResponseBody.argtypes = [c_void_p]
_lib.getResponseBody.restype = c_char_p

# Certificate functions
_lib.responseHasCertificate.argtypes = [c_void_p]
_lib.responseHasCertificate.restype = c_bool

_lib.responseIsVerified.argtypes = [c_void_p]
_lib.responseIsVerified.restype = c_bool

_lib.responseIsSelfSigned.argtypes = [c_void_p]
_lib.responseIsSelfSigned.restype = c_bool

# Server functions
_lib.createServer.argtypes = [c_bool, c_bool, c_char_p, c_char_p, c_char_p]
_lib.createServer.restype = c_void_p

_lib.destroyServer.argtypes = [c_void_p]
_lib.destroyServer.restype = None

# Initialize library (optional, done by first client creation)
_lib.initObiwan()

# Helper functions
def checkError():
    """Check if an error occurred during the last operation"""
    return _lib.hasError()

def takeError():
    """Get the error message from the last operation that failed"""
    error = _lib.getLastError()
    if error:
        return error.decode('utf-8')
    return None

class Response:
    """Represents a response from a Gemini server"""
    
    def __init__(self, handle):
        """Create a response object from a handle"""
        self._handle = handle
        self._status = _lib.getResponseStatus(handle)
        
        meta_ptr = _lib.getResponseMeta(handle)
        self._meta = meta_ptr.decode('utf-8') if meta_ptr else ""
        
        # Body is fetched on demand to avoid unnecessary memory usage
        self._body_cached = None
    
    def __del__(self):
        """Clean up resources"""
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyResponse(self._handle)
            self._handle = None
    
    @property
    def status(self):
        """Get the response status code"""
        return self._status
    
    @property
    def meta(self):
        """Get the response meta information"""
        return self._meta
    
    def body(self):
        """Get the response body content"""
        if self._body_cached is None and self._handle and self.status == Status.SUCCESS:
            body_ptr = _lib.getResponseBody(self._handle)
            if body_ptr:
                self._body_cached = body_ptr.decode('utf-8')
            else:
                self._body_cached = ""
        return self._body_cached
    
    def hasCertificate(self):
        """Check if the server provided a certificate"""
        if self._handle:
            return _lib.responseHasCertificate(self._handle)
        return False
    
    def isVerified(self):
        """Check if the server certificate is verified against a trusted root"""
        if self._handle:
            return _lib.responseIsVerified(self._handle)
        return False
    
    def isSelfSigned(self):
        """Check if the server certificate is self-signed"""
        if self._handle:
            return _lib.responseIsSelfSigned(self._handle)
        return False
    
    def __str__(self):
        body_len = len(self.body()) if self.body() else 0
        cert_info = ""
        if self.hasCertificate():
            cert_status = "verified" if self.isVerified() else "self-signed" if self.isSelfSigned() else "invalid"
            cert_info = f", Certificate: {cert_status}"
        
        return f"Status: {self.status}, Meta: {self.meta}, Body: {body_len} bytes{cert_info}"

class ObiwanClient:
    """Gemini protocol client"""
    
    def __init__(self, max_redirects=5, cert_file="", key_file=""):
        """Create a new Gemini client"""
        self._handle = _lib.createClient(
            max_redirects,
            cert_file.encode('utf-8') if cert_file else b"",
            key_file.encode('utf-8') if key_file else b""
        )
        if not self._handle:
            error = takeError()
            if error:
                raise RuntimeError(f"Failed to create ObiwanClient: {error}")
            else:
                raise RuntimeError("Failed to create ObiwanClient")
    
    def __del__(self):
        self.close()
    
    def close(self):
        """Close the client and free resources"""
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyClient(self._handle)
            self._handle = None
    
    def request(self, url):
        """Make a request to a Gemini server"""
        if not self._handle:
            raise RuntimeError("Client is closed")
        
        response_handle = _lib.requestUrl(self._handle, url.encode('utf-8'))
        
        if not response_handle:
            error = takeError()
            if error:
                raise RuntimeError(f"Request failed: {error}")
            else:
                raise RuntimeError("Request failed")
        
        return Response(response_handle)

class ObiwanServer:
    """Gemini protocol server"""
    
    def __init__(self, reuse_addr=True, reuse_port=False, cert_file="", key_file="", session_id=""):
        """Create a new Gemini server"""
        self._handle = _lib.createServer(
            reuse_addr, 
            reuse_port,
            cert_file.encode('utf-8') if cert_file else b"", 
            key_file.encode('utf-8') if key_file else b"",
            session_id.encode('utf-8') if session_id else b""
        )
        if not self._handle:
            error = takeError()
            if error:
                raise RuntimeError(f"Failed to create ObiwanServer: {error}")
            else:
                raise RuntimeError("Failed to create ObiwanServer")
    
    def __del__(self):
        self.close()
    
    def close(self):
        """Close the server and free resources"""
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyServer(self._handle)
            self._handle = None