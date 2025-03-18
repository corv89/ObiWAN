const std = @import("std");

pub const Status = enum(u8) {
    input = 10 = 0,
    sensitive_input = 11 = 1,
    success = 20 = 2,
    temp_redirect = 30 = 3,
    redirect = 31 = 4,
    temp_error = 40 = 5,
    server_unavailable = 41 = 6,
    cgierror = 42 = 7,
    proxy_error = 43 = 8,
    slowdown = 44 = 9,
    error = 50 = 10,
    not_found = 51 = 11,
    gone = 52 = 12,
    proxy_refused = 53 = 13,
    malformed_request = 59 = 14,
    certificate_required = 60 = 15,
    certificate_unauthorized = 61 = 16,
    certificate_not_valid = 62 = 17,
};

pub const ObiwanClient = opaque {
    extern fn obiwan_obiwan_client_unref(self: *ObiwanClient) callconv(.C) void;
    pub inline fn deinit(self: *ObiwanClient) void {
        return obiwan_obiwan_client_unref(self);
    }

    extern fn obiwan_new_obiwan_client(max_redirects: isize, cert_file: [*:0]const u8, key_file: [*:0]const u8) callconv(.C) ObiwanClient;
    /// Creates a new synchronous Gemini protocol client.
    /// 
    /// This function creates a synchronous client for making Gemini protocol requests.
    /// The client handles TLS connections with proper certificate verification for the
    /// Gemini protocol's security model, which includes support for self-signed certificates.
    /// 
    /// Parameters:
    /// maxRedirects: Maximum number of redirects to follow automatically (default: 5)
    /// certFile: Optional path to client certificate file in PEM format (for client authentication)
    /// keyFile: Optional path to client private key file in PEM format (for client authentication)
    /// 
    /// Returns:
    /// A new ObiwanClient instance ready for making requests
    /// 
    /// Raises:
    /// ObiwanError: If certificate files are specified but cannot be loaded
    /// 
    /// Example:
    /// ```nim
    /// let client = newObiwanClient()
    /// let response = client.request("gemini://example.com/")
    /// if response.status == Status.Success:
    /// let content = response.body()
    /// echo content
    /// ```
    pub inline fn init(max_redirects: isize, cert_file: [:0]const u8, key_file: [:0]const u8) ObiwanClient {
        return obiwan_new_obiwan_client(max_redirects, cert_file.ptr, key_file.ptr);
    }

    extern fn obiwan_obiwan_client_get_max_redirects(self: *ObiwanClient) callconv(.C) Natural;
    pub inline fn getMaxRedirects(self: *ObiwanClient) Natural {
        return obiwan_obiwan_client_get_max_redirects(self);
    }

    extern fn obiwan_obiwan_client_set_max_redirects(self: *ObiwanClient, value: Natural) callconv(.C) void;
    pub inline fn setMaxRedirects(self: *ObiwanClient, value: Natural) void {
        return obiwan_obiwan_client_set_max_redirects(self, value);
    }

    extern fn obiwan_obiwan_client_request(self: ObiwanClient, url: [*:0]const u8) callconv(.C) Response;
    pub inline fn request(self: ObiwanClient, url: [:0]const u8) Response {
        return obiwan_obiwan_client_request(self, url.ptr);
    }

    extern fn obiwan_obiwan_client_close(self: ObiwanClient) callconv(.C) void;
    /// Manually closes the client's connection to the server.
    /// 
    /// This function explicitly closes the TLS socket connection to the server.
    /// Normally, this is handled automatically by the body() method, but you can
    /// use this method to close the connection early or if you don't need to
    /// retrieve the body content.
    /// 
    /// Parameters:
    /// client: The ObiwanClient or AsyncObiwanClient whose connection to close
    /// 
    /// Example:
    /// ```nim
    /// let client = newObiwanClient()
    /// let response = client.request("gemini://example.com/")
    /// # Close without reading the body
    /// client.close()
    /// ```
    pub inline fn close(self: ObiwanClient) void {
        return obiwan_obiwan_client_close(self);
    }
};

pub const ObiwanServer = opaque {
    extern fn obiwan_obiwan_server_unref(self: *ObiwanServer) callconv(.C) void;
    pub inline fn deinit(self: *ObiwanServer) void {
        return obiwan_obiwan_server_unref(self);
    }

    extern fn obiwan_new_obiwan_server(reuse_addr: bool, reuse_port: bool, cert_file: [*:0]const u8, key_file: [*:0]const u8, session_id: [*:0]const u8) callconv(.C) ObiwanServer;
    /// Creates a new synchronous Gemini protocol server.
    /// 
    /// This function creates a synchronous server for handling Gemini protocol requests.
    /// A TLS certificate and private key are required for the server to function, as
    /// the Gemini protocol mandates secure connections.
    /// 
    /// The server supports optional client certificate verification, which can be used
    /// to implement authentication. Client certificates are made available to request
    /// handlers through the Request.certificate property.
    /// 
    /// Parameters:
    /// reuseAddr: Allow reusing local addresses (default: true)
    /// reusePort: Allow multiple bindings to same port (default: false)
    /// certFile: Path to server certificate file in PEM format (required for production)
    /// keyFile: Path to server private key file in PEM format (required for production)
    /// sessionId: Optional custom session ID for TLS session resumption
    /// 
    /// Returns:
    /// A new ObiwanServer instance that can be used with serve()
    /// 
    /// Raises:
    /// ObiwanError: If certificate or key files cannot be loaded
    /// 
    /// Note:
    /// If sessionId is not provided, a random one will be generated.
    /// For testing, you can omit certFile and keyFile, but for production use,
    /// valid certificate and key files are required.
    pub inline fn init(reuse_addr: bool, reuse_port: bool, cert_file: [:0]const u8, key_file: [:0]const u8, session_id: [:0]const u8) ObiwanServer {
        return obiwan_new_obiwan_server(reuse_addr, reuse_port, cert_file.ptr, key_file.ptr, session_id.ptr);
    }

    extern fn obiwan_obiwan_server_get_reuse_addr(self: *ObiwanServer) callconv(.C) bool;
    pub inline fn getReuseAddr(self: *ObiwanServer) bool {
        return obiwan_obiwan_server_get_reuse_addr(self);
    }

    extern fn obiwan_obiwan_server_set_reuse_addr(self: *ObiwanServer, value: bool) callconv(.C) void;
    pub inline fn setReuseAddr(self: *ObiwanServer, value: bool) void {
        return obiwan_obiwan_server_set_reuse_addr(self, value);
    }

    extern fn obiwan_obiwan_server_get_reuse_port(self: *ObiwanServer) callconv(.C) bool;
    pub inline fn getReusePort(self: *ObiwanServer) bool {
        return obiwan_obiwan_server_get_reuse_port(self);
    }

    extern fn obiwan_obiwan_server_set_reuse_port(self: *ObiwanServer, value: bool) callconv(.C) void;
    pub inline fn setReusePort(self: *ObiwanServer, value: bool) void {
        return obiwan_obiwan_server_set_reuse_port(self, value);
    }
};

pub const Response = opaque {
    extern fn obiwan_response_unref(self: *Response) callconv(.C) void;
    pub inline fn deinit(self: *Response) void {
        return obiwan_response_unref(self);
    }

    extern fn obiwan_response_get_status(self: *Response) callconv(.C) Status;
    pub inline fn getStatus(self: *Response) Status {
        return obiwan_response_get_status(self);
    }

    extern fn obiwan_response_set_status(self: *Response, value: Status) callconv(.C) void;
    pub inline fn setStatus(self: *Response, value: Status) void {
        return obiwan_response_set_status(self, value);
    }

    extern fn obiwan_response_get_meta(self: *Response) callconv(.C) [*:0]const u8;
    pub inline fn getMeta(self: *Response) [:0]const u8 {
        return std.mem.span(obiwan_response_get_meta(self));
    }

    extern fn obiwan_response_set_meta(self: *Response, value: [*:0]const u8) callconv(.C) void;
    pub inline fn setMeta(self: *Response, value: [:0]const u8) void {
        return obiwan_response_set_meta(self, value.ptr);
    }

    extern fn obiwan_response_body(self: Response) callconv(.C) [*:0]const u8;
    pub inline fn body(self: Response) [:0]const u8 {
        return std.mem.span(obiwan_response_body(self));
    }

    extern fn obiwan_response_has_certificate(self: Response) callconv(.C) bool;
    /// Checks if a certificate is present in the transaction.
    /// 
    /// This is useful to determine if a client or server provided a certificate
    /// during the TLS handshake, which is optional in the Gemini protocol.
    /// 
    /// Parameters:
    /// transaction: A request or response object
    /// 
    /// Returns:
    /// `true` if a certificate is present, `false` otherwise
    pub inline fn hasCertificate(self: Response) bool {
        return obiwan_response_has_certificate(self);
    }

    extern fn obiwan_response_is_verified(self: Response) callconv(.C) bool;
    /// Checks if a certificate chain is fully verified against a trusted root.
    /// 
    /// Returns `true` when the certificate chain is verified up to a known trusted
    /// root certificate with no verification issues. This typically means the certificate
    /// was issued by a Certificate Authority that the system trusts.
    /// 
    /// Parameters:
    /// transaction: A request or response object containing certificate information
    /// 
    /// Returns:
    /// `true` if the certificate is fully verified, `false` otherwise
    pub inline fn isVerified(self: Response) bool {
        return obiwan_response_is_verified(self);
    }

    extern fn obiwan_response_is_self_signed(self: Response) callconv(.C) bool;
    /// Determines if a certificate is likely self-signed by checking verification flags.
    /// 
    /// Returns `true` when the certificate has only trust issues but no other validation
    /// problems, which typically indicates a self-signed certificate. This is common
    /// in the Gemini ecosystem where many servers use self-signed certificates.
    /// 
    /// This helps implement the Trust-On-First-Use (TOFU) security model recommended
    /// for Gemini clients.
    /// 
    /// Parameters:
    /// transaction: A request or response object containing certificate information
    /// 
    /// Returns:
    /// `true` if the certificate appears to be self-signed, `false` otherwise
    pub inline fn isSelfSigned(self: Response) bool {
        return obiwan_response_is_self_signed(self);
    }
};

extern fn obiwan_check_error() callconv(.C) bool;
pub inline fn checkError() bool {
    return obiwan_check_error();
}

extern fn obiwan_take_error() callconv(.C) [*:0]const u8;
pub inline fn takeError() [:0]const u8 {
    return std.mem.span(obiwan_take_error());
}

