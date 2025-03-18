#ifndef INCLUDE_OBIWAN_H
#define INCLUDE_OBIWAN_H

#include <stdint.h>

typedef char Status;
#define INPUT = 10 0
#define SENSITIVE_INPUT = 11 1
#define SUCCESS = 20 2
#define TEMP_REDIRECT = 30 3
#define REDIRECT = 31 4
#define TEMP_ERROR = 40 5
#define SERVER_UNAVAILABLE = 41 6
#define CGIERROR = 42 7
#define PROXY_ERROR = 43 8
#define SLOWDOWN = 44 9
#define ERROR = 50 10
#define NOT_FOUND = 51 11
#define GONE = 52 12
#define PROXY_REFUSED = 53 13
#define MALFORMED_REQUEST = 59 14
#define CERTIFICATE_REQUIRED = 60 15
#define CERTIFICATE_UNAUTHORIZED = 61 16
#define CERTIFICATE_NOT_VALID = 62 17

struct ObiwanClient;

struct ObiwanServer;

struct Response;

struct ObiwanClient {

  private:

  uint64_t reference;

  public:

  ObiwanClient(int64_t maxRedirects, const char* certFile, const char* keyFile);

  Natural getMaxRedirects();
  void setMaxRedirects(Natural value);

  void free();

  Response request(const char* url);

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
  void close();

};

struct ObiwanServer {

  private:

  uint64_t reference;

  public:

  ObiwanServer(bool reuseAddr, bool reusePort, const char* certFile, const char* keyFile, const char* sessionId);

  bool getReuseAddr();
  void setReuseAddr(bool value);

  bool getReusePort();
  void setReusePort(bool value);

  void free();

};

struct Response {

  private:

  uint64_t reference;

  public:

  Status getStatus();
  void setStatus(Status value);

  const char* getMeta();
  void setMeta(const char* value);

  void free();

  const char* body();

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
  bool hasCertificate();

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
  bool isVerified();

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
  bool isSelfSigned();

};

extern "C" {

void obiwan_obiwan_client_unref(ObiwanClient obiwan_client);

ObiwanClient obiwan_new_obiwan_client(int64_t max_redirects, const char* cert_file, const char* key_file);

Natural obiwan_obiwan_client_get_max_redirects(ObiwanClient obiwan_client);

void obiwan_obiwan_client_set_max_redirects(ObiwanClient obiwan_client, Natural value);

Response obiwan_obiwan_client_request(ObiwanClient client, const char* url);

void obiwan_obiwan_client_close(ObiwanClient client);

void obiwan_obiwan_server_unref(ObiwanServer obiwan_server);

ObiwanServer obiwan_new_obiwan_server(bool reuse_addr, bool reuse_port, const char* cert_file, const char* key_file, const char* session_id);

bool obiwan_obiwan_server_get_reuse_addr(ObiwanServer obiwan_server);

void obiwan_obiwan_server_set_reuse_addr(ObiwanServer obiwan_server, bool value);

bool obiwan_obiwan_server_get_reuse_port(ObiwanServer obiwan_server);

void obiwan_obiwan_server_set_reuse_port(ObiwanServer obiwan_server, bool value);

void obiwan_response_unref(Response response);

Status obiwan_response_get_status(Response response);

void obiwan_response_set_status(Response response, Status value);

const char* obiwan_response_get_meta(Response response);

void obiwan_response_set_meta(Response response, const char* value);

const char* obiwan_response_body(Response response);

bool obiwan_response_has_certificate(Response transaction);

bool obiwan_response_is_verified(Response transaction);

bool obiwan_response_is_self_signed(Response transaction);

bool obiwan_check_error();

const char* obiwan_take_error();

}

ObiwanClient::ObiwanClient(int64_t maxRedirects, const char* certFile, const char* keyFile) {
  this->reference = obiwan_new_obiwan_client(maxRedirects, certFile, keyFile).reference;
}

Natural ObiwanClient::getMaxRedirects(){
  return obiwan_obiwan_client_get_max_redirects(*this);
}

void ObiwanClient::setMaxRedirects(Natural value){
  obiwan_obiwan_client_set_max_redirects(*this, value);
}

void ObiwanClient::free(){
  obiwan_obiwan_client_unref(*this);
}

Response ObiwanClient::request(const char* url) {
  return obiwan_obiwan_client_request(*this, url);
};

void ObiwanClient::close() {
  obiwan_obiwan_client_close(*this);
};

ObiwanServer::ObiwanServer(bool reuseAddr, bool reusePort, const char* certFile, const char* keyFile, const char* sessionId) {
  this->reference = obiwan_new_obiwan_server(reuseAddr, reusePort, certFile, keyFile, sessionId).reference;
}

bool ObiwanServer::getReuseAddr(){
  return obiwan_obiwan_server_get_reuse_addr(*this);
}

void ObiwanServer::setReuseAddr(bool value){
  obiwan_obiwan_server_set_reuse_addr(*this, value);
}

bool ObiwanServer::getReusePort(){
  return obiwan_obiwan_server_get_reuse_port(*this);
}

void ObiwanServer::setReusePort(bool value){
  obiwan_obiwan_server_set_reuse_port(*this, value);
}

void ObiwanServer::free(){
  obiwan_obiwan_server_unref(*this);
}

Status Response::getStatus(){
  return obiwan_response_get_status(*this);
}

void Response::setStatus(Status value){
  obiwan_response_set_status(*this, value);
}

const char* Response::getMeta(){
  return obiwan_response_get_meta(*this);
}

void Response::setMeta(const char* value){
  obiwan_response_set_meta(*this, value);
}

void Response::free(){
  obiwan_response_unref(*this);
}

const char* Response::body() {
  return obiwan_response_body(*this);
};

bool Response::hasCertificate() {
  return obiwan_response_has_certificate(*this);
};

bool Response::isVerified() {
  return obiwan_response_is_verified(*this);
};

bool Response::isSelfSigned() {
  return obiwan_response_is_self_signed(*this);
};

bool checkError() {
  return obiwan_check_error();
};

const char* takeError() {
  return obiwan_take_error();
};

#endif
