var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");
var ArrayType = require('ref-array-napi');

var dll = {};

function obiwanException(message) {
  this.message = message;
  this.name = 'obiwanException';
}

const Status = 'int8'

ObiwanClient = Struct({'nimRef': 'uint64'});
ObiwanClient.prototype.isNull = function(){
  return this.nimRef == 0;
};
ObiwanClient.prototype.isEqual = function(other){
  return this.nimRef == other.nimRef;
};
ObiwanClient.prototype.unref = function(){
  return dll.obiwan_obiwan_client_unref(this)
};
function newObiwanClient(max_redirects, cert_file, key_file){
  var result = dll.obiwan_new_obiwan_client(max_redirects, cert_file, key_file)
  const registry = new FinalizationRegistry(function(obj) {
    console.log("js unref")
    obj.unref()
  });
  registry.register(result, null);
  return result
}
Object.defineProperty(ObiwanClient.prototype, 'maxRedirects', {
  get: function() {return dll.obiwan_obiwan_client_get_max_redirects(this)},
  set: function(v) {dll.obiwan_obiwan_client_set_max_redirects(this, v)}
});

ObiwanClient.prototype.request = function(url){
  result = dll.obiwan_obiwan_client_request(this, url)
  return result
}

/**
 * Manually closes the client's connection to the server.
 * 
 * This function explicitly closes the TLS socket connection to the server.
 * Normally, this is handled automatically by the body() method, but you can
 * use this method to close the connection early or if you don't need to
 * retrieve the body content.
 * 
 * Parameters:
 *   client: The ObiwanClient or AsyncObiwanClient whose connection to close
 * 
 * Example:
 *   ```nim
 *   let client = newObiwanClient()
 *   let response = client.request("gemini://example.com/")
 *   # Close without reading the body
 *   client.close()
 *   ```
 */
ObiwanClient.prototype.close = function(){
  dll.obiwan_obiwan_client_close(this)
}

ObiwanServer = Struct({'nimRef': 'uint64'});
ObiwanServer.prototype.isNull = function(){
  return this.nimRef == 0;
};
ObiwanServer.prototype.isEqual = function(other){
  return this.nimRef == other.nimRef;
};
ObiwanServer.prototype.unref = function(){
  return dll.obiwan_obiwan_server_unref(this)
};
function newObiwanServer(reuse_addr, reuse_port, cert_file, key_file, session_id){
  var result = dll.obiwan_new_obiwan_server(reuse_addr, reuse_port, cert_file, key_file, session_id)
  const registry = new FinalizationRegistry(function(obj) {
    console.log("js unref")
    obj.unref()
  });
  registry.register(result, null);
  return result
}
Object.defineProperty(ObiwanServer.prototype, 'reuseAddr', {
  get: function() {return dll.obiwan_obiwan_server_get_reuse_addr(this)},
  set: function(v) {dll.obiwan_obiwan_server_set_reuse_addr(this, v)}
});
Object.defineProperty(ObiwanServer.prototype, 'reusePort', {
  get: function() {return dll.obiwan_obiwan_server_get_reuse_port(this)},
  set: function(v) {dll.obiwan_obiwan_server_set_reuse_port(this, v)}
});

Response = Struct({'nimRef': 'uint64'});
Response.prototype.isNull = function(){
  return this.nimRef == 0;
};
Response.prototype.isEqual = function(other){
  return this.nimRef == other.nimRef;
};
Response.prototype.unref = function(){
  return dll.obiwan_response_unref(this)
};
Object.defineProperty(Response.prototype, 'status', {
  get: function() {return dll.obiwan_response_get_status(this)},
  set: function(v) {dll.obiwan_response_set_status(this, v)}
});
Object.defineProperty(Response.prototype, 'meta', {
  get: function() {return dll.obiwan_response_get_meta(this)},
  set: function(v) {dll.obiwan_response_set_meta(this, v)}
});

Response.prototype.body = function(){
  result = dll.obiwan_response_body(this)
  return result
}

/**
 * Checks if a certificate is present in the transaction.
 * 
 * This is useful to determine if a client or server provided a certificate
 * during the TLS handshake, which is optional in the Gemini protocol.
 * 
 * Parameters:
 *   transaction: A request or response object
 * 
 * Returns:
 *   `true` if a certificate is present, `false` otherwise
 */
Response.prototype.hasCertificate = function(){
  result = dll.obiwan_response_has_certificate(this)
  return result
}

/**
 * Checks if a certificate chain is fully verified against a trusted root.
 * 
 * Returns `true` when the certificate chain is verified up to a known trusted
 * root certificate with no verification issues. This typically means the certificate
 * was issued by a Certificate Authority that the system trusts.
 * 
 * Parameters:
 *   transaction: A request or response object containing certificate information
 * 
 * Returns:
 *   `true` if the certificate is fully verified, `false` otherwise
 */
Response.prototype.isVerified = function(){
  result = dll.obiwan_response_is_verified(this)
  return result
}

/**
 * Determines if a certificate is likely self-signed by checking verification flags.
 * 
 * Returns `true` when the certificate has only trust issues but no other validation
 * problems, which typically indicates a self-signed certificate. This is common
 * in the Gemini ecosystem where many servers use self-signed certificates.
 * 
 * This helps implement the Trust-On-First-Use (TOFU) security model recommended
 * for Gemini clients.
 * 
 * Parameters:
 *   transaction: A request or response object containing certificate information
 * 
 * Returns:
 *   `true` if the certificate appears to be self-signed, `false` otherwise
 */
Response.prototype.isSelfSigned = function(){
  result = dll.obiwan_response_is_self_signed(this)
  return result
}

function checkError(){
  result = dll.obiwan_check_error()
  return result
}

function takeError(){
  result = dll.obiwan_take_error()
  return result
}


var dllPath = ""
if(process.platform == "win32") {
  dllPath = __dirname + '/obiwan.dll'
} else if (process.platform == "darwin") {
  dllPath = __dirname + '/libobiwan.dylib'
} else {
  dllPath = __dirname + '/libobiwan.so'
}

dll = ffi.Library(dllPath, {
  'obiwan_obiwan_client_unref': ['void', [ObiwanClient]],
  'obiwan_new_obiwan_client': [ObiwanClient, ['int64', 'string', 'string']],
  'obiwan_obiwan_client_get_max_redirects': [Natural, [ObiwanClient]],
  'obiwan_obiwan_client_set_max_redirects': ['void', [ObiwanClient, Natural]],
  'obiwan_obiwan_client_request': [Response, [ObiwanClient, 'string']],
  'obiwan_obiwan_client_close': ['void', [ObiwanClient]],
  'obiwan_obiwan_server_unref': ['void', [ObiwanServer]],
  'obiwan_new_obiwan_server': [ObiwanServer, ['bool', 'bool', 'string', 'string', 'string']],
  'obiwan_obiwan_server_get_reuse_addr': ['bool', [ObiwanServer]],
  'obiwan_obiwan_server_set_reuse_addr': ['void', [ObiwanServer, 'bool']],
  'obiwan_obiwan_server_get_reuse_port': ['bool', [ObiwanServer]],
  'obiwan_obiwan_server_set_reuse_port': ['void', [ObiwanServer, 'bool']],
  'obiwan_response_unref': ['void', [Response]],
  'obiwan_response_get_status': [Status, [Response]],
  'obiwan_response_set_status': ['void', [Response, Status]],
  'obiwan_response_get_meta': ['string', [Response]],
  'obiwan_response_set_meta': ['void', [Response, 'string']],
  'obiwan_response_body': ['string', [Response]],
  'obiwan_response_has_certificate': ['bool', [Response]],
  'obiwan_response_is_verified': ['bool', [Response]],
  'obiwan_response_is_self_signed': ['bool', [Response]],
  'obiwan_check_error': ['bool', []],
  'obiwan_take_error': ['string', []],
});

exports.Status = Status
exports.INPUT = 10 = 0
exports.SENSITIVE_INPUT = 11 = 1
exports.SUCCESS = 20 = 2
exports.TEMP_REDIRECT = 30 = 3
exports.REDIRECT = 31 = 4
exports.TEMP_ERROR = 40 = 5
exports.SERVER_UNAVAILABLE = 41 = 6
exports.CGIERROR = 42 = 7
exports.PROXY_ERROR = 43 = 8
exports.SLOWDOWN = 44 = 9
exports.ERROR = 50 = 10
exports.NOT_FOUND = 51 = 11
exports.GONE = 52 = 12
exports.PROXY_REFUSED = 53 = 13
exports.MALFORMED_REQUEST = 59 = 14
exports.CERTIFICATE_REQUIRED = 60 = 15
exports.CERTIFICATE_UNAUTHORIZED = 61 = 16
exports.CERTIFICATE_NOT_VALID = 62 = 17
exports.ObiwanClientType = ObiwanClient
exports.ObiwanClient = newObiwanClient
exports.ObiwanServerType = ObiwanServer
exports.ObiwanServer = newObiwanServer
exports.ResponseType = Response
exports.checkError = checkError
exports.takeError = takeError
