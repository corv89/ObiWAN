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

# Find library path - try multiple locations
locations = [
    os.path.join(os.path.dirname(__file__), "..", "..", "build", _lib_name),
    os.path.join(os.path.dirname(__file__), "..", "..", _lib_name),
    os.path.join(os.environ.get("DYLD_LIBRARY_PATH", "."), _lib_name),
    os.path.join(os.getcwd(), "build", _lib_name)
]

_lib_path = None
for path in locations:
    if os.path.exists(path):
        _lib_path = path
        break

if _lib_path is None:
    raise RuntimeError(f"Could not find {_lib_name} in any of these locations: {locations}")

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
    """Represents a response from a Gemini server"""
    
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
    """Gemini protocol client"""
    
    def __init__(self, max_redirects=5, cert_file="", key_file=""):
        """Create a new Gemini client"""
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
        """Close the client and free resources"""
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyClient(self._handle)
            self._handle = None
    
    def request(self, url):
        """Make a request to a Gemini server"""
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
    """Gemini protocol server"""
    
    def __init__(self, reuse_addr=True, reuse_port=False, cert_file="", key_file="", session_id=""):
        """Create a new Gemini server"""
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
        """Close the server and free resources"""
        if hasattr(self, '_handle') and self._handle:
            _lib.destroyServer(self._handle)
            self._handle = None