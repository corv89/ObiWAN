# ObiWAN Language Bindings

This directory contains language bindings for ObiWAN, allowing you to use the Gemini protocol library from multiple programming languages.

## Available Bindings

The following languages are supported:

- C
- Python
- Node.js (example provided, needs implementation)

## Building the Bindings

To build the bindings, run:

```bash
nimble bindings
```

This will:
1. Build the shared library in `build/libobiwan.so`
2. Generate the C header file in `bindings/generated/obiwan.h`
3. Generate the Python module in `bindings/generated/python/`

> **Note**: On macOS, you may need to manually create a symlink from `libobiwan.so` to `libobiwan.dylib` in the build directory.

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

```c
#include "../generated/obiwan.h"

int main() {
    // Initialize the library
    initObiwan();
    
    // Create a client
    ObiwanClientHandle client = createClient(5, "", "");
    
    // Make a request
    ObiwanResponseData response;
    requestUrl(client, "gemini://example.com/", &response);
    
    // Use the response
    printf("Status: %d\n", response.status);
    printf("Meta: %s\n", response.meta);
    if (response.hasBody) {
        printf("Body: %s\n", response.body);
    }
    
    // Clean up
    destroyClient(client);
    
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

- `c_example.c`: A simple Gemini client in C
- `python_example.py`: A simple Gemini client in Python
- `nodejs_example.js`: A simple Gemini client in Node.js (placeholder)

## Implementation Details

The bindings are implemented using a Nim wrapper library that:

1. Creates a C-compatible interface to the ObiWAN library
2. Handles memory management and string conversion
3. Provides a simplified API that abstracts away complex details

The core functionality was implemented with:

- C bindings via a wrapper Nim file that exports C-compatible functions
- Python bindings via ctypes to load and use the shared library
- Node.js bindings use a similar approach with the FFI module

## Limitations

- Asynchronous operations are not fully supported in the C or Python APIs
- Error handling is simplified compared to the native Nim API
- The bindings focus on the client-side API, with limited server support
- Memory management requires careful attention, especially in C