# mbedTLS (3.6.2) C bindings

{.pragma: mbedtls, importc, header: "<mbedtls/ssl.h>".}
{.pragma: mbedtlsNetSockets, importc, header: "<mbedtls/net_sockets.h>".}
{.pragma: mbedtlsCrypto, importc, header: "<mbedtls/entropy.h>".}
{.pragma: mbedtlsRandom, importc, header: "<mbedtls/ctr_drbg.h>".}
{.pragma: mbedtlsCerts, importc, header: "<mbedtls/x509_crt.h>".}
{.pragma: mbedtlsPsa, importc, header: "<psa/crypto.h>".}

# Basic types
type
  mbedtls_ssl_context* {.mbedtls.} = object
  mbedtls_ssl_config* {.mbedtls.} = object
  mbedtls_entropy_context* {.mbedtlsCrypto.} = object
  mbedtls_ctr_drbg_context* {.mbedtlsRandom.} = object
  mbedtls_x509_crt* {.mbedtlsCerts.} = object
  mbedtls_pk_context* {.mbedtls.} = object
  mbedtls_net_context* {.mbedtlsNetSockets.} = object
    fd*: cint

# Constants
# These are defined in the mbedTLS headers
{.pragma: mbedtlsConstants, importc, nodecl.}

# TLS version constants
type
  TlsVersion* = enum
    TLS_V10 = 0x0301 # TLS 1.0 (not recommended)
    TLS_V11 = 0x0302 # TLS 1.1 (not recommended)
    TLS_V12 = 0x0303 # TLS 1.2 (minimum recommended)
    TLS_V13 = 0x0304 # TLS 1.3 (preferred)

var
  MBEDTLS_SSL_IS_CLIENT* {.mbedtlsConstants, header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_SSL_IS_SERVER* {.mbedtlsConstants, header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_SSL_TRANSPORT_STREAM* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_SSL_PRESET_DEFAULT* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_SSL_VERIFY_NONE* {.mbedtlsConstants, header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_SSL_VERIFY_OPTIONAL* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_SSL_VERIFY_REQUIRED* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_ERR_SSL_WANT_READ* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_ERR_SSL_WANT_WRITE* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY* {.mbedtlsConstants,
      header: "<mbedtls/ssl.h>".}: cint
  MBEDTLS_ERR_NET_SEND_FAILED* {.mbedtlsConstants,
      header: "<mbedtls/net_sockets.h>".}: cint
  MBEDTLS_ERR_NET_RECV_FAILED* {.mbedtlsConstants,
      header: "<mbedtls/net_sockets.h>".}: cint
  MBEDTLS_ERR_X509_CERT_VERIFY_FAILED* {.mbedtlsConstants,
      header: "<mbedtls/x509_crt.h>".}: cint
  MBEDTLS_NET_PROTO_TCP* {.mbedtlsConstants,
      header: "<mbedtls/net_sockets.h>".}: cint
  MBEDTLS_X509_BADCERT_NOT_TRUSTED* {.mbedtlsConstants,
      header: "<mbedtls/x509_crt.h>".}: cuint
      
  # TLS 1.3 cipher suite constants - manually defined with their standard values
  # These are defined directly instead of imported because they might not be available in all builds
  MBEDTLS_TLS_AES_128_GCM_SHA256* = 0x1301.cint
  MBEDTLS_TLS_AES_256_GCM_SHA384* = 0x1302.cint
  MBEDTLS_TLS_CHACHA20_POLY1305_SHA256* = 0x1303.cint

# Core SSL functions
proc mbedtls_ssl_init*(ctx: ptr mbedtls_ssl_context) {.mbedtls.}
proc mbedtls_ssl_config_init*(conf: ptr mbedtls_ssl_config) {.mbedtls.}
proc mbedtls_ssl_config_defaults*(conf: ptr mbedtls_ssl_config, endpoint: cint,
    transport: cint, preset: cint): cint {.mbedtls.}
proc mbedtls_ssl_conf_rng*(conf: ptr mbedtls_ssl_config, f_rng: pointer,
    p_rng: pointer) {.mbedtls.}
proc mbedtls_ssl_conf_authmode*(conf: ptr mbedtls_ssl_config,
    authmode: cint) {.mbedtls.}
proc mbedtls_ssl_conf_ciphersuites*(conf: ptr mbedtls_ssl_config,
    ciphersuites: ptr cint) {.mbedtls.}
proc mbedtls_ssl_setup*(ssl: ptr mbedtls_ssl_context,
    conf: ptr mbedtls_ssl_config): cint {.mbedtls.}
proc mbedtls_ssl_set_hostname*(ssl: ptr mbedtls_ssl_context,
    hostname: cstring): cint {.mbedtls.}
proc mbedtls_ssl_set_bio*(ssl: ptr mbedtls_ssl_context, ctx: pointer,
    f_send: pointer, f_recv: pointer, f_recv_timeout: pointer) {.mbedtls.}
proc mbedtls_ssl_handshake*(ssl: ptr mbedtls_ssl_context): cint {.mbedtls.}
proc mbedtls_ssl_read*(ssl: ptr mbedtls_ssl_context, buf: pointer,
    len: cuint): cint {.mbedtls.}
proc mbedtls_ssl_write*(ssl: ptr mbedtls_ssl_context, buf: pointer,
    len: cuint): cint {.mbedtls.}
proc mbedtls_ssl_close_notify*(ssl: ptr mbedtls_ssl_context): cint {.mbedtls.}
proc mbedtls_ssl_get_verify_result*(ssl: ptr mbedtls_ssl_context): cuint {.mbedtls.}
proc mbedtls_ssl_get_peer_cert*(ssl: ptr mbedtls_ssl_context): ptr mbedtls_x509_crt {.mbedtls.}
proc mbedtls_ssl_conf_verify*(conf: ptr mbedtls_ssl_config, f_vrfy: pointer,
    p_vrfy: pointer) {.mbedtls.}

# Certificate functions
proc mbedtls_x509_crt_init*(crt: ptr mbedtls_x509_crt) {.mbedtlsCerts.}
proc mbedtls_x509_crt_parse_file*(crt: ptr mbedtls_x509_crt,
    path: cstring): cint {.mbedtlsCerts.}
proc mbedtls_pk_init*(ctx: ptr mbedtls_pk_context) {.mbedtls.}
# Import the platform-specific version of mbedtls_pk_parse_keyfile
when defined(macosx) or defined(isMacOS):
  # macOS version has 5 parameters
  proc mbedtls_pk_parse_keyfile*(ctx: ptr mbedtls_pk_context, path: cstring, password: cstring,
                                f_rng: pointer,
                                    p_rng: pointer): cint {.mbedtls.}
else:
  # Linux version has 3 parameters
  proc mbedtls_pk_parse_keyfile*(ctx: ptr mbedtls_pk_context, path: cstring,
      password: cstring): cint {.mbedtls.}
proc mbedtls_ssl_conf_own_cert*(conf: ptr mbedtls_ssl_config,
    cert: ptr mbedtls_x509_crt, key: ptr mbedtls_pk_context): cint {.mbedtls.}

# Entropy and random number generation
proc mbedtls_entropy_init*(ctx: ptr mbedtls_entropy_context) {.mbedtlsCrypto.}
proc mbedtls_ctr_drbg_init*(ctx: ptr mbedtls_ctr_drbg_context) {.mbedtlsRandom.}
proc mbedtls_ctr_drbg_seed*(ctx: ptr mbedtls_ctr_drbg_context,
    f_entropy: pointer, p_entropy: pointer, custom: pointer,
    len: csize_t): cint {.mbedtlsRandom.}
proc mbedtls_ctr_drbg_random*(p_rng: pointer, output: pointer,
    output_len: csize_t): cint {.mbedtlsRandom, cdecl.}
proc mbedtls_entropy_func*(data: pointer, output: pointer,
    len: csize_t): cint {.mbedtlsCrypto, cdecl.}

# Network functions
proc mbedtls_net_init*(ctx: ptr mbedtls_net_context) {.mbedtlsNetSockets.}
proc mbedtls_net_connect*(ctx: ptr mbedtls_net_context, host: cstring,
    port: cstring, proto: cint): cint {.mbedtlsNetSockets.}
proc mbedtls_net_set_nonblock*(ctx: ptr mbedtls_net_context): cint {.mbedtlsNetSockets.}
proc mbedtls_net_bind*(ctx: ptr mbedtls_net_context, bind_ip: cstring,
    port: cstring, proto: cint): cint {.mbedtlsNetSockets.}
proc mbedtls_net_accept*(bind_ctx: ptr mbedtls_net_context,
    client_ctx: ptr mbedtls_net_context, client_ip: cstring,
    client_ip_len: csize_t, client_port: ptr uint16): cint {.mbedtlsNetSockets.}
proc mbedtls_net_free*(ctx: ptr mbedtls_net_context) {.mbedtlsNetSockets.}

proc mbedtls_net_send*(ctx: pointer, buf: pointer,
    len: csize_t): cint {.importc, header: "<mbedtls/net_sockets.h>", cdecl.}
proc mbedtls_net_recv*(ctx: pointer, buf: pointer,
    len: csize_t): cint {.importc, header: "<mbedtls/net_sockets.h>", cdecl.}

# Utility functions
proc mbedtls_strerror*(errnum: cint, buffer: cstring,
    buflen: csize_t) {.importc, header: "<mbedtls/error.h>".}
proc mbedtls_sha256*(input: pointer, ilen: csize_t, output: pointer,
    is224: cint): cint {.importc, header: "<mbedtls/sha256.h>".}

# PSA Crypto functions (required for TLS 1.3)
proc psa_crypto_init*(): cint {.mbedtlsPsa.}

# X509 utility functions
proc mbedtls_x509_dn_gets*(buf: cstring, size: csize_t,
    dn: pointer): cint {.importc, header: "<mbedtls/x509_crt.h>".}
proc mbedtls_x509_crt_info*(buf: cstring, size: csize_t, prefix: cstring,
    crt: ptr mbedtls_x509_crt): cint {.importc, header: "<mbedtls/x509_crt.h>".}
