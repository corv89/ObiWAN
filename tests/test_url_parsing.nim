## Test suite for URL parsing in ObiWAN
##
## This test suite validates ObiWAN's URL parsing implementation,
## focusing on proper handling of Gemini URLs according to the specification.

import unittest
import obiwan/url
import std/uri except parseUrl # Needed for conversion test

suite "URL Parsing Tests":
  test "URL Conversion":
    # Test converting between Uri and Url types
    let urlStr = "gemini://example.com/path?query=value#fragment"
    let url = parseUrl(urlStr)
    
    # Convert to standard library Uri and back
    let uri = toUri(url)
    let backToUrl = fromUri(uri)
    
    check url.scheme == backToUrl.scheme
    check url.hostname == backToUrl.hostname
    check url.path == backToUrl.path
    check $url.query == $backToUrl.query
    check url.fragment == backToUrl.fragment
    
  test "Gemini URL Specific Functions":
    # Test Gemini-specific helpers
    let urlStr = "gemini://example.com/"
    let url = parseUrl(urlStr)
    
    # Test geminiPort
    check geminiPort(url) == 1965
    
    # Test with explicit port
    let urlWithPort = parseUrl("gemini://example.com:8965/")
    check geminiPort(urlWithPort) == 8965
    
    # Test validateGeminiUrl
    check validateGeminiUrl(url) == true
    let invalidScheme = parseUrl("http://example.com/")
    check validateGeminiUrl(invalidScheme) == false
  test "Basic URL Parsing":
    # Test basic URL parsing
    let urlStr = "gemini://example.com/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.port == "" # Default port isn't populated by parseUrl
    check url.path == "/"

  test "URL with Port":
    # Test URL with explicit port
    let urlStr = "gemini://example.com:1965/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.port == "1965"
    check url.path == "/"

  test "URL with Query Parameters":
    # Test URL with query parameters
    let urlStr = "gemini://example.com/search?query=test&page=1"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.path == "/search"
    check url.query.len > 0
    check url.query["query"] == "test"
    check url.query["page"] == "1"
    
    # Test query parameter convenience functions
    check "query" in url.query
    check "nonexistent" notin url.query
    check url.query.getOrDefault("page", "default") == "1"
    check url.query.getOrDefault("nonexistent", "default") == "default"

  test "URL with IPv4 Address":
    # Test URL with IPv4 address instead of hostname
    let urlStr = "gemini://127.0.0.1/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "127.0.0.1"
    check url.path == "/"

  test "URL with IPv6 Address":
    # Test URL with IPv6 address
    let urlStr = "gemini://[::1]/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "[::1]" # Webby keeps the brackets in IPv6 addresses
    check url.path == "/"

  test "URL with IPv6 Address and Port":
    # Test URL with IPv6 address and port
    let urlStr = "gemini://[::1]:1965/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "[::1]" # Webby keeps the brackets in IPv6 addresses
    check url.port == "1965"
    check url.path == "/"

  test "URL with expanded IPv6 Address":
    # Test URL with a full IPv6 address
    let urlStr = "gemini://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "[2001:0db8:85a3:0000:0000:8a2e:0370:7334]"
    check url.path == "/"

  test "URL with compressed IPv6 Address":
    # Test URL with compressed IPv6 address (with ::)
    let urlStr = "gemini://[2001:db8::8a2e:370:7334]/"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "[2001:db8::8a2e:370:7334]"
    check url.path == "/"

  test "URL with invalid scheme":
    # Test URL with invalid scheme (not gemini://)
    let urlStr = "http://example.com/"
    let url = parseUrl(urlStr)

    check url.scheme == "http"
    check url.hostname == "example.com"
    check url.path == "/"

    # In a real application, we would validate that the scheme is "gemini"
    # This test is to ensure we can detect non-Gemini URLs

  test "URL with empty hostname":
    # Test URL with empty hostname
    let urlStr = "gemini:///"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == ""
    check url.path == "/"

  test "URL with unusual characters in path":
    # Test URL with unusual characters in path
    let urlStr = "gemini://example.com/~user/file%20with%20spaces.txt"
    let url = parseUrl(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.path == "/~user/file with spaces.txt"
