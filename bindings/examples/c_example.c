#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
        return 1;
    }

    // Make a request to a Gemini server
    const char* url = "gemini://gemini.circumlunar.space/";
    printf("Sending request to: %s\n", url);

    ObiwanResponseData response;
    int result = requestUrl(client, url, &response);
    
    if (result != 0) {
        printf("Failed to get response\n");
        destroyClient(client);
        return 1;
    }

    // Get the status code and meta information
    printf("\nResponse received:\n");
    printf("Status: %d\n", response.status);
    printf("Meta: %s\n", response.meta);

    // Only try to read the body if the status is 20 (Success)
    if (response.status == SUCCESS && response.hasBody) {
        printf("\nFetching body content...\n");
        printf("\n--- CONTENT ---\n%s\n--- END OF CONTENT ---\n", response.body);
    } else {
        printf("\nNot fetching body as status is not 20 (Success)\n");
    }

    // Clean up
    destroyClient(client);
    printf("\nConnection closed\n");

    return 0;
}