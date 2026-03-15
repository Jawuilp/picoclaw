# ============================================================
# Stage 1: Build the picoclaw binary
# ============================================================
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git make nodejs npm

WORKDIR /src

# Install pnpm globally
RUN npm install -g pnpm

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build web launcher (includes frontend)
COPY . .
RUN make build && make build-launcher

# ============================================================
# Stage 2: Minimal runtime image
# ============================================================
FROM alpine:3.23

RUN apk add --no-cache ca-certificates tzdata curl

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost:18800/health || exit 1

EXPOSE 18800

# Copy binary (web launcher) and CLI, and config
COPY --from=builder /src/build/picoclaw-launcher /usr/local/bin/picoclaw-web
COPY --from=builder /src/build/picoclaw /usr/local/bin/picoclaw
COPY --from=builder /src/config.json /tmp/config.json

# Create non-root user and group
RUN addgroup -g 1000 picoclaw && \
    adduser -D -u 1000 -G picoclaw picoclaw && \
    mkdir -p /home/picoclaw/.picoclaw && \
    cp /tmp/config.json /home/picoclaw/.picoclaw/config.json && \
    mkdir -p /home/picoclaw/.picoclaw/workspace && \
    chown -R picoclaw:picoclaw /home/picoclaw

# Switch to non-root user
USER picoclaw

ENTRYPOINT ["/usr/local/bin/picoclaw-web", "-public", "-port", "${PORT:-18800}"]
