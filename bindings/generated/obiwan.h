/* ObiWAN C API Header
 * This file contains declarations for the ObiWAN Gemini protocol library C bindings
 */
#ifndef OBIWAN_H
#define OBIWAN_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Platform-specific symbol name handling
 *
 * NOTE ON MACOS COMPATIBILITY:
 * 
 * On macOS, we recommend using dynamic loading with dlopen/dlsym:
 * - Direct linking on macOS is problematic due to how symbol names are handled
 * - Dynamic loading with dlopen/dlsym works consistently across all platforms
 * - See bindings/examples/c_example_dlopen.c for an example
 */

/* Standard function declaration macro */
#define OBIWAN_FUNC(returnType, name, params) \
  extern returnType name params

/*
 * Handle Types
 * These are opaque pointers for ObiWAN objects
 */
typedef void* ObiwanClientHandle;
typedef void* ObiwanServerHandle;
typedef void* ObiwanResponseHandle;

/*
 * Status Codes
 * Gemini protocol response status codes
 */
enum ObiwanStatus {
    /* 1X: Input */
    OBIWAN_INPUT = 10,              /* Input required from user */
    OBIWAN_SENSITIVE_INPUT = 11,    /* Sensitive input (password) required */
    
    /* 2X: Success */
    OBIWAN_SUCCESS = 20,            /* Success, content follows */
    
    /* 3X: Redirect */
    OBIWAN_TEMP_REDIRECT = 30,      /* Temporary redirect to another URL */
    OBIWAN_REDIRECT = 31,           /* Permanent redirect to another URL */
    
    /* 4X: Temporary Failure */
    OBIWAN_TEMP_ERROR = 40,         /* Temporary server failure */
    OBIWAN_SERVER_UNAVAILABLE = 41, /* Server unavailable (capacity issues) */
    OBIWAN_CGI_ERROR = 42,          /* CGI script failure */
    OBIWAN_PROXY_ERROR = 43,        /* Proxy request failure */
    OBIWAN_SLOWDOWN = 44,           /* Request rate too high, slow down */
    
    /* 5X: Permanent Failure */
    OBIWAN_ERROR = 50,              /* Permanent server failure */
    OBIWAN_NOT_FOUND = 51,          /* Resource not found */
    OBIWAN_GONE = 52,               /* Resource permanently gone */
    OBIWAN_PROXY_REFUSED = 53,      /* Proxy request refused */
    OBIWAN_MALFORMED_REQUEST = 59,  /* Malformed request syntax */
    
    /* 6X: Client Certificate Required */
    OBIWAN_CERT_REQUIRED = 60,      /* Client certificate required */
    OBIWAN_CERT_UNAUTHORIZED = 61,  /* Certificate not authorized for resource */
    OBIWAN_CERT_NOT_VALID = 62      /* Certificate not valid or expired */
};

/*
 * Response data structure (legacy format, prefer using separate functions)
 */
typedef struct {
    int status;               /* Response status code */
    const char* meta;         /* Meta information field */
    const char* body;         /* Response body content (if available) */
    bool hasBody;             /* Indicates if body contains data */
    bool hasCertificate;      /* Whether server provided a certificate */
    bool isVerified;          /* Whether certificate is verified */
    bool isSelfSigned;        /* Whether certificate is self-signed */
} ObiwanResponseData;

/*
 * Library Initialization
 */

/**
 * Initialize the ObiWAN library.
 * This must be called before any other functions.
 */
OBIWAN_FUNC(void, initObiwan, (void));

/*
 * Error Handling
 */

/**
 * Check if an error occurred during the last operation.
 * @return true if an error occurred, false otherwise
 */
OBIWAN_FUNC(bool, hasError, (void));

/**
 * Get the error message from the last operation that failed.
 * This clears the error state.
 * @return Error message or NULL if no error
 */
OBIWAN_FUNC(const char*, getLastError, (void));

/*
 * Client API
 */

/**
 * Create a new Gemini client.
 * 
 * @param maxRedirects Maximum number of redirects to follow (recommended: 5)
 * @param certFile Path to client certificate file (may be empty)
 * @param keyFile Path to client key file (may be empty)
 * @return Client handle or NULL on error
 */
OBIWAN_FUNC(ObiwanClientHandle, createClient, (int maxRedirects, const char* certFile, const char* keyFile));

/**
 * Destroy a client and free resources.
 * 
 * @param client Client handle to destroy
 */
OBIWAN_FUNC(void, destroyClient, (ObiwanClientHandle client));

/**
 * Make a request to a Gemini server.
 * 
 * @param client Client handle
 * @param url Gemini URL to request (must start with gemini://)
 * @return Response handle or NULL on error
 */
OBIWAN_FUNC(ObiwanResponseHandle, requestUrl, (ObiwanClientHandle client, const char* url));

/*
 * Response API
 */

/**
 * Destroy a response object and free resources.
 * 
 * @param response Response handle to destroy
 */
OBIWAN_FUNC(void, destroyResponse, (ObiwanResponseHandle response));

/**
 * Get the status code from a response.
 * 
 * @param response Response handle
 * @return Status code or -1 on error
 */
OBIWAN_FUNC(int, getResponseStatus, (ObiwanResponseHandle response));

/**
 * Get the meta information from a response.
 * 
 * @param response Response handle
 * @return Meta string or NULL on error
 */
OBIWAN_FUNC(const char*, getResponseMeta, (ObiwanResponseHandle response));

/**
 * Get the body content from a response.
 * 
 * @param response Response handle
 * @return Body content or NULL if not available or on error
 */
OBIWAN_FUNC(const char*, getResponseBody, (ObiwanResponseHandle response));

/**
 * Check if the server provided a certificate.
 * 
 * @param response Response handle
 * @return true if certificate is present, false otherwise
 */
OBIWAN_FUNC(bool, responseHasCertificate, (ObiwanResponseHandle response));

/**
 * Check if the server certificate is verified against a trusted root.
 * 
 * @param response Response handle
 * @return true if certificate is verified, false otherwise
 */
OBIWAN_FUNC(bool, responseIsVerified, (ObiwanResponseHandle response));

/**
 * Check if the server certificate is self-signed.
 * 
 * @param response Response handle
 * @return true if certificate is self-signed, false otherwise
 */
OBIWAN_FUNC(bool, responseIsSelfSigned, (ObiwanResponseHandle response));

/*
 * Server API
 */

/**
 * Create a new Gemini server.
 * 
 * @param reuseAddr Allow reuse of local addresses
 * @param reusePort Allow multiple bindings to the same port
 * @param certFile Path to server certificate (required)
 * @param keyFile Path to server key (required)
 * @param sessionId Optional session identifier
 * @return Server handle or NULL on error
 */
OBIWAN_FUNC(ObiwanServerHandle, createServer, (bool reuseAddr, bool reusePort, const char* certFile, const char* keyFile, const char* sessionId));

/**
 * Destroy a server and free resources.
 * 
 * @param server Server handle to destroy
 */
OBIWAN_FUNC(void, destroyServer, (ObiwanServerHandle server));

#ifdef __cplusplus
}
#endif

#endif /* OBIWAN_H */