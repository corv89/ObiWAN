# ObiWAN Bindings Examples

This directory contains examples of how to use the ObiWAN Gemini protocol library bindings from different languages.

## Building and Running the Examples

A Makefile is provided to make it easy to build and run the examples:

```bash
# Build the ObiWAN shared library first (if not already built)
make library

# Build all examples
make

# Clean the build
make clean

# Run the examples
make run
```

### Building the Library Manually

If you want to build the shared library manually:

```bash
# From the project root
nimble bindings
```

## C Example

There are multiple ways to use the ObiWAN library from C:

### Dynamic Loading Approach (RECOMMENDED)

The most reliable and portable approach is to use dynamic loading with `dlopen`/`dlsym`, which handles platform-specific symbol names automatically:

```c
void* lib = dlopen("path/to/libobiwan.so", RTLD_LAZY);
if (lib) {
    void (*initObiwan)(void) = dlsym(lib, "initObiwan");
    // Use functions...
    dlclose(lib);
}
```

This approach works on all platforms without needing to worry about symbol name prefixing. See `c_example_dlopen.c` for a complete example.

Key advantages:
- Automatically handles the underscore prefix on macOS
- Works consistently across all platforms
- Allows for more flexible error handling
- Can check if functions exist before using them

### Standard Header Approach

The ObiWAN header file (`obiwan.h`) uses a standard approach to declare functions:

```c
#define OBIWAN_FUNC(returnType, name, params) \
  extern returnType name params
```

This allows declarations like:

```c
OBIWAN_FUNC(void, initObiwan, (void));
```

The example `c_example.c` demonstrates this approach.

#### Platform-Specific Considerations

**Linux/Windows**: Direct linking generally works well on these platforms.

**macOS**: Direct linking on macOS is problematic due to how symbol names are handled:

1. macOS adds an underscore prefix to symbols in compiled object files
2. This creates a mismatch between exported symbols and how the linker expects them
3. For macOS users, we strongly recommend the dynamic loading approach instead

## Python Example

The Python bindings use `ctypes` to load the library and handle platform-specific details:

```python
# Determine library name based on platform
if platform.system() == "Windows":
    _lib_name = "obiwan.dll"
elif platform.system() == "Darwin":
    _lib_name = "libobiwan.dylib"
else:
    _lib_name = "libobiwan.so"

# Load the library
_lib = ctypes.CDLL(_lib_path)
```

## Node.js Example

The Node.js bindings provide a clean, JavaScript-friendly interface to the ObiWAN library:

```js
const obiwan = require('obiwan');

const client = new obiwan.ObiwanClient();
const response = client.request('gemini://example.com/');

console.log(`Status: ${response.status}`);
console.log(`Body: ${response.body()}`);
```

## Notes on Symbol Naming

- On macOS, symbols in dynamic libraries have an underscore prefix added automatically
- When using direct linking, the header file needs to account for this using `asm("_name")` attributes
- When using dynamic loading, `dlsym` automatically handles the platform-specific naming
- Most higher-level language bindings (Python, Node.js) use dynamic loading under the hood