FROM nimlang/nim:2.2.2-alpine

WORKDIR /app

# Install mbedTLS and build dependencies
RUN apk --no-cache add mbedtls-dev build-base openssl pkgconfig

# Copy the source code
COPY . .

# Setup to use system mbedTLS
RUN sh ./use_system_mbedtls.sh

# Build the ObiWAN server and client
RUN nimble install
RUN nimble buildall

# Create and set content directory
RUN mkdir -p /app/content
RUN echo "# Welcome to ObiWAN Gemini Server\n\nThis server is running inside an Alpine Linux Docker container." > /app/content/index.gmi

# Generate self-signed certificates for testing
RUN mkdir -p /app/certs && \
    openssl req -x509 -newkey rsa:4096 -keyout /app/certs/privkey.pem -out /app/certs/cert.pem -days 365 -nodes -subj "/CN=localhost"

# Expose the Gemini protocol port
EXPOSE 1965

# Run the server (optimized size, SSL, etc.)
CMD ["/app/build/obiwan-server", "--cert=/app/certs/cert.pem", "--key=/app/certs/privkey.pem", "--docroot=/app/content", "--port=1965"]
