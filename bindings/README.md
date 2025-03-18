# ObiWAN Language Bindings

This directory contains language bindings for ObiWAN, allowing you to use the Gemini protocol library from multiple programming languages.

## Available Bindings

The following languages are supported:

- C (with direct linking and dynamic loading options)
- Python
- Node.js

## Building the Bindings

To build the bindings, run:

```bash
nimble bindings
```

This will:
1. Build the shared library in `build/libobiwan.so`
2. Generate the C header file in `bindings/generated/obiwan.h`
3. Generate the Python module in `bindings/generated/python/`
4. Generate Node.js bindings in `bindings/generated/node/`

### Platform-Specific Details

**Linux/Windows**: The bindings should work seamlessly on these platforms.

**macOS**: Due to how macOS handles symbol names, there are a few things to note:

1. Library extension: macOS uses `.dylib` instead of `.so`
   ```bash
   # Create a symlink from .so to .dylib
   cd build
   ln -s libobiwan.so libobiwan.dylib
   ```

2. Symbol name prefixing: macOS automatically adds an underscore prefix to all symbols in compiled object files.

   To handle this, we provide two approaches:
   
   - **Dynamic loading (recommended)**: Using `dlopen`/`dlsym` automatically handles the underscore prefix. See `examples/c_example_dlopen.c`.
   
   - **Direct linking**: Our header uses a special macro to handle macOS symbol prefixing. While this works in many cases, you may still encounter linker errors on some macOS configurations.

   If you encounter errors like `undefined symbol: _initObiwan`, please use the dynamic loading approach instead.

## API Overview

The C and Python APIs provide a simplified interface to the Gemini protocol:

### Client API

- Create a client with `createClient()` (C) or `ObiwanClient()` (Python)
- Make requests with `requestUrl()` (C) or `client.request()` (Python)
- Clean up resources with `destroyClient()` (C) or `client.close()` (Python)

### Server API

- Create a server with `createServer()` (C) or `ObiwanServer()` (Python)
- The C API requires you to implement your own request handler
- Clean up resources with `destroyServer()` (C) or `server.close()` (Python)

## Using the Bindings

### C

#### Direct Linking Approach

```c
#include "../generated/obiwan.h"

int main() {
    // Initialize the library
    initObiwan();
    
    // Create a client with max redirects = 5, no client cert or key
    ObiwanClientHandle client = createClient(5, "", "");
    if (client == NULL) {
        printf("Error: %s\n", getLastError());
        return 1;
    }
    
    // Make a request
    ObiwanResponseHandle response = requestUrl(client, "gemini://example.com/");
    if (response == NULL) {
        printf("Error: %s\n", getLastError());
        destroyClient(client);
        return 1;
    }
    
    // Get response details
    int status = getResponseStatus(response);
    const char* meta = getResponseMeta(response);
    
    printf("Status: %d\n", status);
    printf("Meta: %s\n", meta);
    
    if (status == OBIWAN_SUCCESS) {
        const char* body = getResponseBody(response);
        if (body != NULL) {
            printf("Body: %s\n", body);
        }
    }
    
    // Check certificate info
    printf("Has certificate: %s\n", responseHasCertificate(response) ? "yes" : "no");
    printf("Is verified: %s\n", responseIsVerified(response) ? "yes" : "no");
    printf("Is self-signed: %s\n", responseIsSelfSigned(response) ? "yes" : "no");
    
    // Clean up
    destroyResponse(response);
    destroyClient(client);
    
    return 0;
}
```

#### Dynamic Loading Approach (more portable, especially for macOS)

```c
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdbool.h>

// Define handle types and enums
typedef void* ObiwanClientHandle;
typedef void* ObiwanResponseHandle;

enum ObiwanStatus {
    OBIWAN_SUCCESS = 20,
    // ... other status codes
};

int main() {
    // Load the library
    void* lib = dlopen("./build/libobiwan.so", RTLD_LAZY);
    if (!lib) {
        printf("Error loading library: %s\n", dlerror());
        return 1;
    }
    
    // Get function pointers
    void (*initObiwan)(void) = dlsym(lib, "initObiwan");
    bool (*hasError)(void) = dlsym(lib, "hasError");
    const char* (*getLastError)(void) = dlsym(lib, "getLastError");
    ObiwanClientHandle (*createClient)(int, const char*, const char*) = dlsym(lib, "createClient");
    ObiwanResponseHandle (*requestUrl)(ObiwanClientHandle, const char*) = dlsym(lib, "requestUrl");
    // ... other functions
    
    // Use the functions just like in the direct linking approach
    initObiwan();
    ObiwanClientHandle client = createClient(5, "", "");
    // ...
    
    // Close the library when done
    dlclose(lib);
    return 0;
}
```

### Python

```python
from python.obiwan import ObiwanClient, Status

# Create a client
client = ObiwanClient(max_redirects=5)

# Make a request
response = client.request("gemini://example.com/")

# Use the response
print(f"Status: {response.status}")
print(f"Meta: {response.meta}")
if response.status == Status.SUCCESS:
    print(f"Body: {response.body}")

# Clean up
client.close()
```

## Examples

Check the `examples` directory for complete working examples for each supported language:

### C Examples

- `c_example.c`: A simple Gemini client in C using direct linking
- `c_example_with_fixed_header.c`: Example using the updated header with improved macOS support
- `c_example_dlopen.c`: A portable example using dynamic loading (recommended for macOS)
- `macos_test.c`: A minimal test file for verifying macOS compatibility

### Other Languages

- `python_example.py`: A simple Gemini client in Python
- `nodejs_example.js`: A simple Gemini client in Node.js

The `examples` directory also contains a detailed README with platform-specific notes and considerations.

## Implementation Details

The bindings are implemented using a Nim wrapper library that:

1. Creates a C-compatible interface to the ObiWAN library
2. Handles memory management and string conversion
3. Provides a simplified API that abstracts away complex details

The core functionality was implemented with:

- C bindings via a wrapper Nim file that exports C-compatible functions
- Python bindings via ctypes to load and use the shared library
- Node.js bindings use a similar approach with the FFI module

## Limitations and Known Issues

### Feature Limitations

- Asynchronous operations are not fully supported in the C or Python APIs
- Error handling is simplified compared to the native Nim API
- The bindings focus on the client-side API, with limited server support
- Memory management requires careful attention, especially in C

### Platform-Specific Issues

- **macOS Symbol Prefixing**: macOS adds an underscore prefix to symbols, which creates significant challenges for direct linking:
  - We have tested multiple approaches to solve this (asm attributes, visibility attributes, direct symbol references) 
  - None of the direct linking approaches work reliably across all macOS environments
  - For macOS users, we strongly recommend using dynamic loading (`dlopen`/`dlsym`), which works reliably and handles symbol name translation automatically
  - See `bindings/examples/c_example_dlopen.c` for a complete working example

- **Library Extensions**: On macOS, you need to create a symlink from `.so` to `.dylib` for the Python and Node.js bindings to work correctly.

- **Windows Support**: The bindings should work on Windows but have not been extensively tested. You may need to adjust paths and library naming conventions.

See the detailed README in the `examples` directory for more information on platform-specific considerations.