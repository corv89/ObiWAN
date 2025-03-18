/**
 * ObiWAN Node.js Bindings TypeScript Definitions
 */

/**
 * Status codes for Gemini responses
 */
export enum Status {
  INPUT = 10,
  SENSITIVE_INPUT = 11,
  SUCCESS = 20,
  TEMP_REDIRECT = 30,
  REDIRECT = 31,
  TEMP_ERROR = 40,
  SERVER_UNAVAILABLE = 41,
  CGI_ERROR = 42,
  PROXY_ERROR = 43,
  SLOWDOWN = 44,
  ERROR = 50,
  NOT_FOUND = 51,
  GONE = 52,
  PROXY_REFUSED = 53,
  MALFORMED_REQUEST = 59,
  CERTIFICATE_REQUIRED = 60,
  CERTIFICATE_UNAUTHORIZED = 61,
  CERTIFICATE_NOT_VALID = 62
}

/**
 * Response from a Gemini server
 */
export class Response {
  /**
   * Status code of the response
   */
  readonly status: number;
  
  /**
   * Meta information from the response
   */
  readonly meta: string;
  
  /**
   * Get the body content
   */
  body(): string | null;
  
  /**
   * Check if the server provided a certificate
   */
  hasCertificate(): boolean;
  
  /**
   * Check if the server certificate is verified
   */
  isVerified(): boolean;
  
  /**
   * Check if the server certificate is self-signed
   */
  isSelfSigned(): boolean;
}

/**
 * Gemini protocol client
 */
export class ObiwanClient implements Disposable {
  /**
   * Create a new Gemini client
   * @param maxRedirects Maximum number of redirects to follow (default: 5)
   * @param certFile Path to client certificate file (optional)
   * @param keyFile Path to client key file (optional)
   */
  constructor(maxRedirects?: number, certFile?: string, keyFile?: string);
  
  /**
   * Make a request to a Gemini server
   * @param url The Gemini URL to request
   */
  request(url: string): Response;
  
  /**
   * Close the client and free resources
   */
  close(): void;
  
  /**
   * Symbol.dispose implementation for resource cleanup
   */
  [Symbol.dispose](): void;
}

/**
 * Gemini protocol server
 */
export class ObiwanServer implements Disposable {
  /**
   * Create a new Gemini server
   * @param reuseAddr Allow reuse of local addresses
   * @param reusePort Allow multiple bindings to the same port
   * @param certFile Path to server certificate (required)
   * @param keyFile Path to server key (required)
   * @param sessionId Optional session identifier
   */
  constructor(
    reuseAddr?: boolean,
    reusePort?: boolean,
    certFile?: string,
    keyFile?: string,
    sessionId?: string
  );
  
  /**
   * Close the server and free resources
   */
  close(): void;
  
  /**
   * Symbol.dispose implementation for resource cleanup
   */
  [Symbol.dispose](): void;
}

/**
 * Check if an error occurred during the last operation
 */
export function checkError(): boolean;

/**
 * Get the error message from the last operation that failed
 */
export function takeError(): string;