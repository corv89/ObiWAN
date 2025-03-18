/**
 * ObiWAN Node.js Bindings - Simplified Mock Implementation
 * A Gemini protocol client and server library
 * 
 * Note: This is a simplified implementation that doesn't require native modules.
 * In a real implementation, you would use ffi-napi to interface with the C library.
 */

// Status codes
const Status = {
  INPUT: 10,
  SENSITIVE_INPUT: 11,
  SUCCESS: 20,
  TEMP_REDIRECT: 30,
  REDIRECT: 31,
  TEMP_ERROR: 40,
  SERVER_UNAVAILABLE: 41,
  CGI_ERROR: 42,
  PROXY_ERROR: 43,
  SLOWDOWN: 44,
  ERROR: 50,
  NOT_FOUND: 51,
  GONE: 52,
  PROXY_REFUSED: 53,
  MALFORMED_REQUEST: 59,
  CERTIFICATE_REQUIRED: 60,
  CERTIFICATE_UNAUTHORIZED: 61,
  CERTIFICATE_NOT_VALID: 62
};

// Mock implementation for demonstration purposes
let hasErrorFlag = false;
let lastErrorMessage = '';

/**
 * Set an error message
 * @param {string} message Error message
 */
function setError(message) {
  hasErrorFlag = true;
  lastErrorMessage = message;
}

/**
 * Check if an error occurred during the last operation
 * @returns {boolean} True if an error occurred
 */
function checkError() {
  return hasErrorFlag;
}

/**
 * Get the error message from the last operation that failed
 * @returns {string} Error message
 */
function takeError() {
  const error = lastErrorMessage;
  hasErrorFlag = false;
  lastErrorMessage = '';
  return error;
}

/**
 * Response from a Gemini server
 */
class Response {
  /**
   * Create a response object
   * @param {number} status Status code
   * @param {string} meta Meta information
   * @param {string} body Body content
   */
  constructor(status, meta, body = null) {
    this._status = status;
    this._meta = meta;
    this._body = body;
    this._hasCertificate = true;
    this._isVerified = false;
    this._isSelfSigned = true;
  }

  /**
   * Get the status code
   * @returns {number} Status code
   */
  get status() {
    return this._status;
  }

  /**
   * Get the meta information
   * @returns {string} Meta information
   */
  get meta() {
    return this._meta;
  }

  /**
   * Get the body content
   * @returns {string|null} Body content
   */
  body() {
    return this._body;
  }

  /**
   * Check if the server provided a certificate
   * @returns {boolean} True if certificate is present
   */
  hasCertificate() {
    return this._hasCertificate;
  }

  /**
   * Check if the server certificate is verified
   * @returns {boolean} True if certificate is verified
   */
  isVerified() {
    return this._isVerified;
  }

  /**
   * Check if the server certificate is self-signed
   * @returns {boolean} True if certificate is self-signed
   */
  isSelfSigned() {
    return this._isSelfSigned;
  }
}

/**
 * ObiWAN Client class
 */
class ObiwanClient {
  /**
   * Create a new Gemini client
   * @param {number} maxRedirects Maximum number of redirects to follow
   * @param {string} certFile Path to client certificate file
   * @param {string} keyFile Path to client key file
   */
  constructor(maxRedirects = 5, certFile = '', keyFile = '') {
    this._maxRedirects = maxRedirects;
    this._certFile = certFile;
    this._keyFile = keyFile;
    this._closed = false;
    
    console.log("Initializing ObiWAN Gemini client");
  }

  /**
   * Close the client and free resources
   */
  close() {
    if (this._closed) {
      return;
    }
    
    this._closed = true;
    console.log("Closing ObiWAN Gemini client");
  }

  /**
   * Make a request to a Gemini server
   * @param {string} url The Gemini URL to request
   * @returns {Response} Response object
   */
  request(url) {
    if (this._closed) {
      setError('Client is closed');
      return null;
    }
    
    if (!url.startsWith('gemini://')) {
      setError('URL must start with gemini://');
      return null;
    }
    
    console.log(`Simulating request to ${url}`);
    
    // This is a mock implementation that returns a hardcoded response
    return new Response(
      Status.SUCCESS,
      'text/gemini',
      `# Welcome to ObiWAN\n\nThis is a simulated Gemini response.\n\n* The real implementation would connect to a Gemini server\n* And return the actual response\n* This is just a mock for demonstration purposes\n`
    );
  }
}

/**
 * ObiWAN Server class
 */
class ObiwanServer {
  /**
   * Create a new Gemini server
   * @param {boolean} reuseAddr Allow reuse of local addresses
   * @param {boolean} reusePort Allow multiple bindings to the same port
   * @param {string} certFile Path to server certificate
   * @param {string} keyFile Path to server key
   * @param {string} sessionId Optional session identifier
   */
  constructor(reuseAddr = true, reusePort = false, certFile = '', keyFile = '', sessionId = '') {
    this._reuseAddr = reuseAddr;
    this._reusePort = reusePort;
    this._certFile = certFile;
    this._keyFile = keyFile;
    this._sessionId = sessionId;
    this._closed = false;
    
    if (!certFile || !keyFile) {
      setError('Certificate and key files are required for server');
      return;
    }
    
    console.log("Initializing ObiWAN Gemini server");
  }

  /**
   * Close the server and free resources
   */
  close() {
    if (this._closed) {
      return;
    }
    
    this._closed = true;
    console.log("Closing ObiWAN Gemini server");
  }
}

// Export public interface
module.exports = {
  ObiwanClient,
  ObiwanServer,
  Response,
  Status,
  checkError,
  takeError
};