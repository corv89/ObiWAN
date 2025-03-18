# Vendor Directory

This directory contains vendored dependencies for ObiWAN.

## mbedTLS

Version: 3.6.2

MbedTLS is a cryptographic and SSL/TLS library that is designed to be easy to use, portable, and compact. It is used by ObiWAN for TLS functionality.

To build mbedTLS:
```
nimble buildmbedtls
```

The mbedTLS submodule is configured to use a specific version (3.6.2) to ensure consistent builds.