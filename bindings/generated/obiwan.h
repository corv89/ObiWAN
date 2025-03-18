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
