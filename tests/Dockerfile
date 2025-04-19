# Use Go base image
FROM golang:1.21-alpine

# Set working directory
WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go.mod and go.sum first to leverage Docker cache
COPY tests/go.mod tests/go.sum ./
RUN go mod download

# Copy test code
COPY tests/*.go ./

# Install test dependencies
RUN go install github.com/stretchr/testify/assert@v1.8.4

# Command to run tests
CMD ["go", "test", "-v", "./..."]
