/* ObiWAN C API - Generated header */
#ifndef OBIWAN_C_H
#define OBIWAN_C_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

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
void initObiwan(void);

/*
 * Error Handling
 */

/**
 * Check if an error occurred during the last operation.
 * @return true if an error occurred, false otherwise
 */
bool hasError(void);

/**
 * Get the error message from the last operation that failed.
 * This clears the error state.
 * @return Error message or NULL if no error
 */
const char* getLastError(void);

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
ObiwanClientHandle createClient(int maxRedirects, const char* certFile, const char* keyFile);

/**
 * Destroy a client and free resources.
 * 
 * @param client Client handle to destroy
 */
void destroyClient(ObiwanClientHandle client);

/**
 * Make a request to a Gemini server.
 * 
 * @param client Client handle
 * @param url Gemini URL to request (must start with gemini://)
 * @return Response handle or NULL on error
 */
ObiwanResponseHandle requestUrl(ObiwanClientHandle client, const char* url);

/*
 * Response API
 */

/**
 * Destroy a response object and free resources.
 * 
 * @param response Response handle to destroy
 */
void destroyResponse(ObiwanResponseHandle response);

/**
 * Get the status code from a response.
 * 
 * @param response Response handle
 * @return Status code or -1 on error
 */
int getResponseStatus(ObiwanResponseHandle response);

/**
 * Get the meta information from a response.
 * 
 * @param response Response handle
 * @return Meta string or NULL on error
 */
const char* getResponseMeta(ObiwanResponseHandle response);

/**
 * Get the body content from a response.
 * 
 * @param response Response handle
 * @return Body content or NULL if not available or on error
 */
const char* getResponseBody(ObiwanResponseHandle response);

/**
 * Check if the server provided a certificate.
 * 
 * @param response Response handle
 * @return true if certificate is present, false otherwise
 */
bool responseHasCertificate(ObiwanResponseHandle response);

/**
 * Check if the server certificate is verified against a trusted root.
 * 
 * @param response Response handle
 * @return true if certificate is verified, false otherwise
 */
bool responseIsVerified(ObiwanResponseHandle response);

/**
 * Check if the server certificate is self-signed.
 * 
 * @param response Response handle
 * @return true if certificate is self-signed, false otherwise
 */
bool responseIsSelfSigned(ObiwanResponseHandle response);

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
ObiwanServerHandle createServer(bool reuseAddr, bool reusePort, const char* certFile, const char* keyFile, const char* sessionId);

/**
 * Destroy a server and free resources.
 * 
 * @param server Server handle to destroy
 */
void destroyServer(ObiwanServerHandle server);

/* 
 * Portability helpers
 */

/* For platforms that need underscore prefix on symbol names (e.g. macOS) */
#ifdef __APPLE__
  #define OBIWAN_SYMBOL(name) _##name
#else
  #define OBIWAN_SYMBOL(name) name
#endif

#ifdef __cplusplus
}
#endif

#endif /* OBIWAN_C_H */