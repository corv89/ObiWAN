from ctypes import *
import os, sys

dir = os.path.dirname(sys.modules["obiwan"].__file__)
if sys.platform == "win32":
  libName = "obiwan.dll"
elif sys.platform == "darwin":
  libName = "libobiwan.dylib"
else:
  libName = "libobiwan.so"
dll = cdll.LoadLibrary(os.path.join(dir, libName))

class obiwanError(Exception):
    pass

class SeqIterator(object):
    def __init__(self, seq):
        self.idx = 0
        self.seq = seq
    def __iter__(self):
        return self
    def __next__(self):
        if self.idx < len(self.seq):
            self.idx += 1
            return self.seq[self.idx - 1]
        else:
            self.idx = 0
            raise StopIteration

Status = c_byte
INPUT = 10 = 0
SENSITIVE_INPUT = 11 = 1
SUCCESS = 20 = 2
TEMP_REDIRECT = 30 = 3
REDIRECT = 31 = 4
TEMP_ERROR = 40 = 5
SERVER_UNAVAILABLE = 41 = 6
CGIERROR = 42 = 7
PROXY_ERROR = 43 = 8
SLOWDOWN = 44 = 9
ERROR = 50 = 10
NOT_FOUND = 51 = 11
GONE = 52 = 12
PROXY_REFUSED = 53 = 13
MALFORMED_REQUEST = 59 = 14
CERTIFICATE_REQUIRED = 60 = 15
CERTIFICATE_UNAUTHORIZED = 61 = 16
CERTIFICATE_NOT_VALID = 62 = 17

class ObiwanClient(Structure):
    _fields_ = [("ref", c_ulonglong)]

    def __bool__(self):
        return self.ref != None

    def __eq__(self, obj):
        return self.ref == obj.ref

    def __del__(self):
        dll.obiwan_obiwan_client_unref(self)

    def __init__(self, max_redirects, cert_file, key_file):
        result = dll.obiwan_new_obiwan_client(max_redirects, cert_file.encode("utf8"), key_file.encode("utf8"))
        self.ref = result

    @property
    def max_redirects(self):
        return dll.obiwan_obiwan_client_get_max_redirects(self)

    @max_redirects.setter
    def max_redirects(self, max_redirects):
        dll.obiwan_obiwan_client_set_max_redirects(self, max_redirects)

    def request(self, url):
        result = dll.obiwan_obiwan_client_request(self, url.encode("utf8"))
        return result

    def close(self):
        """
        Manually closes the client's connection to the server.
        
        This function explicitly closes the TLS socket connection to the server.
        Normally, this is handled automatically by the body() method, but you can
        use this method to close the connection early or if you don't need to
        retrieve the body content.
        
        Parameters:
          client: The ObiwanClient or AsyncObiwanClient whose connection to close
        
        Example:
          ```nim
          let client = newObiwanClient()
          let response = client.request("gemini://example.com/")
          # Close without reading the body
          client.close()
          ```
        """
        dll.obiwan_obiwan_client_close(self)

class ObiwanServer(Structure):
    _fields_ = [("ref", c_ulonglong)]

    def __bool__(self):
        return self.ref != None

    def __eq__(self, obj):
        return self.ref == obj.ref

    def __del__(self):
        dll.obiwan_obiwan_server_unref(self)

    def __init__(self, reuse_addr, reuse_port, cert_file, key_file, session_id):
        result = dll.obiwan_new_obiwan_server(reuse_addr, reuse_port, cert_file.encode("utf8"), key_file.encode("utf8"), session_id.encode("utf8"))
        self.ref = result

    @property
    def reuse_addr(self):
        return dll.obiwan_obiwan_server_get_reuse_addr(self)

    @reuse_addr.setter
    def reuse_addr(self, reuse_addr):
        dll.obiwan_obiwan_server_set_reuse_addr(self, reuse_addr)

    @property
    def reuse_port(self):
        return dll.obiwan_obiwan_server_get_reuse_port(self)

    @reuse_port.setter
    def reuse_port(self, reuse_port):
        dll.obiwan_obiwan_server_set_reuse_port(self, reuse_port)

class Response(Structure):
    _fields_ = [("ref", c_ulonglong)]

    def __bool__(self):
        return self.ref != None

    def __eq__(self, obj):
        return self.ref == obj.ref

    def __del__(self):
        dll.obiwan_response_unref(self)

    @property
    def status(self):
        return dll.obiwan_response_get_status(self)

    @status.setter
    def status(self, status):
        dll.obiwan_response_set_status(self, status)

    @property
    def meta(self):
        return dll.obiwan_response_get_meta(self).decode("utf8")

    @meta.setter
    def meta(self, meta):
        dll.obiwan_response_set_meta(self, meta.encode("utf8"))

    def body(self):
        result = dll.obiwan_response_body(self).decode("utf8")
        return result

    def has_certificate(self):
        """
        Checks if a certificate is present in the transaction.
        
        This is useful to determine if a client or server provided a certificate
        during the TLS handshake, which is optional in the Gemini protocol.
        
        Parameters:
          transaction: A request or response object
        
        Returns:
          `true` if a certificate is present, `false` otherwise
        """
        result = dll.obiwan_response_has_certificate(self)
        return result

    def is_verified(self):
        """
        Checks if a certificate chain is fully verified against a trusted root.
        
        Returns `true` when the certificate chain is verified up to a known trusted
        root certificate with no verification issues. This typically means the certificate
        was issued by a Certificate Authority that the system trusts.
        
        Parameters:
          transaction: A request or response object containing certificate information
        
        Returns:
          `true` if the certificate is fully verified, `false` otherwise
        """
        result = dll.obiwan_response_is_verified(self)
        return result

    def is_self_signed(self):
        """
        Determines if a certificate is likely self-signed by checking verification flags.
        
        Returns `true` when the certificate has only trust issues but no other validation
        problems, which typically indicates a self-signed certificate. This is common
        in the Gemini ecosystem where many servers use self-signed certificates.
        
        This helps implement the Trust-On-First-Use (TOFU) security model recommended
        for Gemini clients.
        
        Parameters:
          transaction: A request or response object containing certificate information
        
        Returns:
          `true` if the certificate appears to be self-signed, `false` otherwise
        """
        result = dll.obiwan_response_is_self_signed(self)
        return result

def check_error():
    result = dll.obiwan_check_error()
    return result

def take_error():
    result = dll.obiwan_take_error().decode("utf8")
    return result

dll.obiwan_obiwan_client_unref.argtypes = [ObiwanClient]
dll.obiwan_obiwan_client_unref.restype = None

dll.obiwan_new_obiwan_client.argtypes = [c_longlong, c_char_p, c_char_p]
dll.obiwan_new_obiwan_client.restype = c_ulonglong

dll.obiwan_obiwan_client_get_max_redirects.argtypes = [ObiwanClient]
dll.obiwan_obiwan_client_get_max_redirects.restype = Natural

dll.obiwan_obiwan_client_set_max_redirects.argtypes = [ObiwanClient, Natural]
dll.obiwan_obiwan_client_set_max_redirects.restype = None

dll.obiwan_obiwan_client_request.argtypes = [ObiwanClient, c_char_p]
dll.obiwan_obiwan_client_request.restype = Response

dll.obiwan_obiwan_client_close.argtypes = [ObiwanClient]
dll.obiwan_obiwan_client_close.restype = None

dll.obiwan_obiwan_server_unref.argtypes = [ObiwanServer]
dll.obiwan_obiwan_server_unref.restype = None

dll.obiwan_new_obiwan_server.argtypes = [c_bool, c_bool, c_char_p, c_char_p, c_char_p]
dll.obiwan_new_obiwan_server.restype = c_ulonglong

dll.obiwan_obiwan_server_get_reuse_addr.argtypes = [ObiwanServer]
dll.obiwan_obiwan_server_get_reuse_addr.restype = c_bool

dll.obiwan_obiwan_server_set_reuse_addr.argtypes = [ObiwanServer, c_bool]
dll.obiwan_obiwan_server_set_reuse_addr.restype = None

dll.obiwan_obiwan_server_get_reuse_port.argtypes = [ObiwanServer]
dll.obiwan_obiwan_server_get_reuse_port.restype = c_bool

dll.obiwan_obiwan_server_set_reuse_port.argtypes = [ObiwanServer, c_bool]
dll.obiwan_obiwan_server_set_reuse_port.restype = None

dll.obiwan_response_unref.argtypes = [Response]
dll.obiwan_response_unref.restype = None

dll.obiwan_response_get_status.argtypes = [Response]
dll.obiwan_response_get_status.restype = Status

dll.obiwan_response_set_status.argtypes = [Response, Status]
dll.obiwan_response_set_status.restype = None

dll.obiwan_response_get_meta.argtypes = [Response]
dll.obiwan_response_get_meta.restype = c_char_p

dll.obiwan_response_set_meta.argtypes = [Response, c_char_p]
dll.obiwan_response_set_meta.restype = None

dll.obiwan_response_body.argtypes = [Response]
dll.obiwan_response_body.restype = c_char_p

dll.obiwan_response_has_certificate.argtypes = [Response]
dll.obiwan_response_has_certificate.restype = c_bool

dll.obiwan_response_is_verified.argtypes = [Response]
dll.obiwan_response_is_verified.restype = c_bool

dll.obiwan_response_is_self_signed.argtypes = [Response]
dll.obiwan_response_is_self_signed.restype = c_bool

dll.obiwan_check_error.argtypes = []
dll.obiwan_check_error.restype = c_bool

dll.obiwan_take_error.argtypes = []
dll.obiwan_take_error.restype = c_char_p

