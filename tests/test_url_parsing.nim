## Test suite for URL parsing in ObiWAN
##
## This test suite validates ObiWAN's URL parsing implementation,
## focusing on proper handling of Gemini URLs according to the specification.

import unittest
import uri

suite "URL Parsing Tests":
  test "Basic URL Parsing":
    # Test basic URL parsing
    let urlStr = "gemini://example.com/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.port == "" # Default port isn't populated by parseUri
    check url.path == "/"

  test "URL with Port":
    # Test URL with explicit port
    let urlStr = "gemini://example.com:1965/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.port == "1965"
    check url.path == "/"

  test "URL with Query Parameters":
    # Test URL with query parameters
    let urlStr = "gemini://example.com/search?query=test&page=1"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.path == "/search"
    check url.query == "query=test&page=1"

  test "URL with IPv4 Address":
    # Test URL with IPv4 address instead of hostname
    let urlStr = "gemini://127.0.0.1/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "127.0.0.1"
    check url.path == "/"

  test "URL with IPv6 Address":
    # Test URL with IPv6 address
    let urlStr = "gemini://[::1]/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "::1" # Nim's parseUri strips the brackets
    check url.path == "/"

  test "URL with IPv6 Address and Port":
    # Test URL with IPv6 address and port
    let urlStr = "gemini://[::1]:1965/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "::1" # Nim's parseUri strips the brackets
    check url.port == "1965"
    check url.path == "/"

  test "URL with expanded IPv6 Address":
    # Test URL with a full IPv6 address
    let urlStr = "gemini://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    check url.path == "/"

  test "URL with compressed IPv6 Address":
    # Test URL with compressed IPv6 address (with ::)
    let urlStr = "gemini://[2001:db8::8a2e:370:7334]/"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "2001:db8::8a2e:370:7334"
    check url.path == "/"

  test "URL with invalid scheme":
    # Test URL with invalid scheme (not gemini://)
    let urlStr = "http://example.com/"
    let url = parseUri(urlStr)

    check url.scheme == "http"
    check url.hostname == "example.com"
    check url.path == "/"

    # In a real application, we would validate that the scheme is "gemini"
    # This test is to ensure we can detect non-Gemini URLs

  test "URL with empty hostname":
    # Test URL with empty hostname
    let urlStr = "gemini:///"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == ""
    check url.path == "/"

  test "URL with unusual characters in path":
    # Test URL with unusual characters in path
    let urlStr = "gemini://example.com/~user/file%20with%20spaces.txt"
    let url = parseUri(urlStr)

    check url.scheme == "gemini"
    check url.hostname == "example.com"
    check url.path == "/~user/file%20with%20spaces.txt"
