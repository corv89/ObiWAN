# ObiWAN TLS Implementation

ObiWAN uses mbedTLS (version 3.6.2) as its TLS implementation with a custom configuration optimized for:

1. Security: TLS 1.3 only
2. Performance: Modern ciphersuites and elliptic curves
3. Binary size: Minimized footprint for embedded and mobile applications

## Configuration Overview

The current configuration focuses on TLS 1.3 with ChaCha20-Poly1305, providing a good balance between security, performance, and size:

### Features

- **Protocol**: TLS 1.3 only (older TLS versions disabled)
- **Ciphersuite**: ChaCha20-Poly1305 with SHA256 only
- **Key Exchange**: Ephemeral mode only
- **Curves**: SECP256R1 and Curve25519
- **Size Optimizations**: 
  - Reduced MPI window size and maximum size
  - Reduced ECP window size and disabled fixed point optimization
  - AES tables stored in ROM instead of RAM
  - Reduced TLS content length buffer to 8KB
  - Removed SHA384/SHA512 support
  - Minimal PSA crypto initialization

## Building

To rebuild mbedTLS with a customized configuration:

1. Modify `mbedtls_config.h` as needed
2. Run:
   ```
   nimble buildmbedtls
   nimble buildall
   ```

## Notes

- For TLS 1.3 functionality, the PSA crypto subsystem is initialized in the `newContext()` function
- The current configuration works with most Gemini servers
- If you need to support servers that only offer TLS 1.2, you'll need to modify the configuration