/**
 * Minimal mbedTLS configuration for ObiWAN
 * Focused on TLS 1.3 with ChaCha20-Poly1305
 * 
 * This configuration optimizes for minimum binary size while maintaining
 * security and functionality for the Gemini protocol.
 * 
 * Based on the reference mbedTLS config with significant optimizations
 * for size and memory usage.
 */

#ifndef MBEDTLS_CONFIG_H
#define MBEDTLS_CONFIG_H

/* System support */
#define MBEDTLS_HAVE_ASM
#define MBEDTLS_HAVE_TIME
#define MBEDTLS_PLATFORM_C
#define MBEDTLS_FS_IO

/* PSA API Support - Required for TLS 1.3 */
#define MBEDTLS_PSA_CRYPTO_C
#define MBEDTLS_USE_PSA_CRYPTO
#define MBEDTLS_PSA_CRYPTO_CONFIG

/* Minimal mbed TLS feature support */
#define MBEDTLS_AES_C                   /* Required for CTR_DRBG */
#define MBEDTLS_AES_ROM_TABLES          /* Store tables in ROM to save RAM */
#define MBEDTLS_ASN1_PARSE_C
#define MBEDTLS_ASN1_WRITE_C            /* Required for certificate handling */
#define MBEDTLS_BASE64_C
#define MBEDTLS_BIGNUM_C
#define MBEDTLS_CIPHER_C
#define MBEDTLS_CTR_DRBG_C
#define MBEDTLS_ENTROPY_C
#define MBEDTLS_ERROR_C
#define MBEDTLS_MD_C
#define MBEDTLS_NET_C                  /* Required for sockets */
#define MBEDTLS_OID_C
#define MBEDTLS_PK_C
#define MBEDTLS_PK_PARSE_C
#define MBEDTLS_PLATFORM_ENTROPY        /* Use platform entropy sources */
#define MBEDTLS_SHA256_C
#define MBEDTLS_SSL_CLI_C
#define MBEDTLS_SSL_SRV_C
#define MBEDTLS_SSL_TLS_C
#define MBEDTLS_X509_CRT_PARSE_C
#define MBEDTLS_X509_USE_C

/* TLS 1.3 Support */
#define MBEDTLS_SSL_PROTO_TLS1_3
#define MBEDTLS_SSL_TLS1_3_KEY_EXCHANGE_MODE_EPHEMERAL_ENABLED
#define MBEDTLS_SSL_TLS1_3_COMPATIBILITY_MODE
#define MBEDTLS_HKDF_C                  /* Required for TLS 1.3 key derivation */

/* ChaCha20-Poly1305 for TLS 1.3 */
#define MBEDTLS_CHACHA20_C
#define MBEDTLS_POLY1305_C
#define MBEDTLS_CHACHAPOLY_C

/* ECC Support - only what's needed */
#define MBEDTLS_ECP_C
#define MBEDTLS_ECP_DP_SECP256R1_ENABLED
#define MBEDTLS_ECP_DP_CURVE25519_ENABLED
#define MBEDTLS_ECDSA_C
#define MBEDTLS_ECDH_C
#define MBEDTLS_PK_HAVE_ECC_KEYS

/* RSA Support - minimal */
#define MBEDTLS_RSA_C
#define MBEDTLS_PKCS1_V15        /* Required for certificate validation */

/* PSA Crypto Requirements for TLS 1.3 */
#define PSA_WANT_ALG_CHACHA20_POLY1305
#define PSA_WANT_ALG_ECDH
#define PSA_WANT_ALG_ECDSA
#define PSA_WANT_ALG_HKDF
#define PSA_WANT_ALG_HKDF_EXTRACT
#define PSA_WANT_ALG_HKDF_EXPAND
#define PSA_WANT_ALG_SHA_256
#define PSA_WANT_ECC_SECP_R1_256
#define PSA_WANT_ECC_MONTGOMERY_255
#define PSA_WANT_KEY_TYPE_AES          /* Required for random generation */
#define PSA_WANT_ALG_ECB_NO_PADDING    /* Required for random generation */

/* Size Optimizations */
#define MBEDTLS_ECP_WINDOW_SIZE 2
#define MBEDTLS_ECP_FIXED_POINT_OPTIM 0
#define MBEDTLS_MPI_WINDOW_SIZE 1
#define MBEDTLS_MPI_MAX_SIZE 64        /* 512 bits, sufficient for 256-bit curves */
#define MBEDTLS_SSL_MAX_CONTENT_LEN 8192  /* Reduced from default 16KB */

/* TLS 1.3 Ciphersuites - only ChaCha20-Poly1305 */
#define MBEDTLS_SSL_TLS1_3_CHACHA20_POLY1305_SHA256  /* Required for TLS 1.3 ChaCha20-Poly1305 */
#define MBEDTLS_SSL_CIPHERSUITES MBEDTLS_TLS_CHACHA20_POLY1305_SHA256

/* Include check_config.h to catch configuration errors */
#include "check_config.h"

#endif /* MBEDTLS_CONFIG_H */