#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <string.h>

// Handle Types
typedef void* ObiwanClientHandle;
typedef void* ObiwanResponseHandle;

// Status Codes
enum ObiwanStatus {
    OBIWAN_INPUT = 10,
    OBIWAN_SENSITIVE_INPUT = 11,
    OBIWAN_SUCCESS = 20,
    OBIWAN_TEMP_REDIRECT = 30,
    OBIWAN_REDIRECT = 31,
    OBIWAN_TEMP_ERROR = 40,
    OBIWAN_SERVER_UNAVAILABLE = 41,
    OBIWAN_CGI_ERROR = 42,
    OBIWAN_PROXY_ERROR = 43,
    OBIWAN_SLOWDOWN = 44,
    OBIWAN_ERROR = 50,
    OBIWAN_NOT_FOUND = 51,
    OBIWAN_GONE = 52,
    OBIWAN_PROXY_REFUSED = 53,
    OBIWAN_MALFORMED_REQUEST = 59,
    OBIWAN_CERT_REQUIRED = 60,
    OBIWAN_CERT_UNAUTHORIZED = 61,
    OBIWAN_CERT_NOT_VALID = 62
};

int main() {
    printf("ObiWAN Gemini Client Example in C (dlopen version)\n");
    printf("=================================================\n\n");

    // Load the library with full path
    void* lib = dlopen("./build/libobiwan.so", RTLD_LAZY);
    if (!lib) {
        printf("Error loading library: %s\n", dlerror());
        return 1;
    }

    // Get pointers to all functions
    void (*initObiwan)(void) = dlsym(lib, "initObiwan");
    bool (*hasError)(void) = dlsym(lib, "hasError");
    const char* (*getLastError)(void) = dlsym(lib, "getLastError");
    ObiwanClientHandle (*createClient)(int, const char*, const char*) = dlsym(lib, "createClient");
    void (*destroyClient)(ObiwanClientHandle) = dlsym(lib, "destroyClient");
    ObiwanResponseHandle (*requestUrl)(ObiwanClientHandle, const char*) = dlsym(lib, "requestUrl");
    int (*getResponseStatus)(ObiwanResponseHandle) = dlsym(lib, "getResponseStatus");
    const char* (*getResponseMeta)(ObiwanResponseHandle) = dlsym(lib, "getResponseMeta");
    const char* (*getResponseBody)(ObiwanResponseHandle) = dlsym(lib, "getResponseBody");
    bool (*responseHasCertificate)(ObiwanResponseHandle) = dlsym(lib, "responseHasCertificate");
    bool (*responseIsVerified)(ObiwanResponseHandle) = dlsym(lib, "responseIsVerified");
    bool (*responseIsSelfSigned)(ObiwanResponseHandle) = dlsym(lib, "responseIsSelfSigned");
    void (*destroyResponse)(ObiwanResponseHandle) = dlsym(lib, "destroyResponse");

    // Check if all functions were found
    if (!initObiwan || !hasError || !getLastError ||
        !createClient || !destroyClient || !requestUrl ||
        !getResponseStatus || !getResponseMeta || !getResponseBody ||
        !responseHasCertificate || !responseIsVerified || !responseIsSelfSigned ||
        !destroyResponse) {
        printf("Error loading symbols: %s\n", dlerror());
        dlclose(lib);
        return 1;
    }

    // Initialize the library
    initObiwan();

    // Create a client
    ObiwanClientHandle client = createClient(5, "", "");
    if (client == NULL) {
        printf("Failed to create client\n");
        if (hasError()) {
            printf("Error: %s\n", getLastError());
        }
        dlclose(lib);
        return 1;
    }

    // Make a request
    const char* url = "gemini://geminiprotocol.net/";
    printf("Sending request to: %s\n", url);

    ObiwanResponseHandle response = requestUrl(client, url);
    if (response == NULL) {
        printf("Failed to get response\n");
        if (hasError()) {
            printf("Error: %s\n", getLastError());
        }
        destroyClient(client);
        dlclose(lib);
        return 1;
    }

    // Get response info
    int status = getResponseStatus(response);
    const char* meta = getResponseMeta(response);

    printf("\nResponse received:\n");
    printf("Status: %d\n", status);
    printf("Meta: %s\n", meta);

    // Certificate info
    printf("\nCertificate info:\n");
    printf("- Has certificate: %s\n", responseHasCertificate(response) ? "yes" : "no");
    printf("- Is verified: %s\n", responseIsVerified(response) ? "yes" : "no");
    printf("- Is self-signed: %s\n", responseIsSelfSigned(response) ? "yes" : "no");

    // Get body if status is success (20)
    if (status == OBIWAN_SUCCESS) {
        printf("\nFetching body content...\n");
        const char* body = getResponseBody(response);
        if (body != NULL) {
            printf("\n--- CONTENT ---\n%s\n--- END OF CONTENT ---\n", body);
        } else {
            printf("\nNo body content available\n");
            if (hasError()) {
                printf("Error: %s\n", getLastError());
            }
        }
    } else {
        printf("\nNot fetching body as status is not 20 (Success)\n");
    }

    // Clean up
    destroyResponse(response);
    destroyClient(client);
    printf("\nConnection closed\n");

    dlclose(lib);
    return 0;
}
