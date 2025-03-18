#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "../generated/obiwan.h"

int main() {
    printf("ObiWAN Gemini Client Example in C\n");
    printf("=================================\n\n");

    // Initialize the library
    initObiwan();

    // Create a new Gemini client with default settings
    ObiwanClientHandle client = createClient(5, "", "");
    if (client == NULL) {
        printf("Failed to create Gemini client\n");
        if (hasError()) {
            printf("Error: %s\n", getLastError());
        }
        return 1;
    }

    // Make a request to a Gemini server
    const char* url = "gemini://geminiprotocol.net/";
    printf("Sending request to: %s\n", url);

    ObiwanResponseHandle response = requestUrl(client, url);

    if (response == NULL) {
        printf("Failed to get response\n");
        if (hasError()) {
            printf("Error: %s\n", getLastError());
        }
        destroyClient(client);
        return 1;
    }

    // Get the status code and meta information
    int status = getResponseStatus(response);
    const char* meta = getResponseMeta(response);

    printf("\nResponse received:\n");
    printf("Status: %d\n", status);
    printf("Meta: %s\n", meta);

    // Certificate information
    printf("\nCertificate info:\n");
    printf("- Has certificate: %s\n", responseHasCertificate(response) ? "yes" : "no");
    printf("- Is verified: %s\n", responseIsVerified(response) ? "yes" : "no");
    printf("- Is self-signed: %s\n", responseIsSelfSigned(response) ? "yes" : "no");

    // Only try to read the body if the status is 20 (Success)
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

    return 0;
}
