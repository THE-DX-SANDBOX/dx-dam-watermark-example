# Multi-stage build for DAM Plugin
FROM node:20-alpine AS builder

# Install build dependencies for native modules (canvas, sharp)
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    cairo-dev \
    pango-dev \
    jpeg-dev \
    giflib-dev \
    librsvg-dev \
    pixman-dev

# --- Build shared package first ---
WORKDIR /shared
COPY shared/package*.json ./
RUN npm ci
COPY shared/ ./
RUN npx tsc

# --- Build server ---
WORKDIR /build

# Copy package files, replace @dam-plugin/shared with local file ref, install deps
COPY server-v1/package*.json ./
RUN sed -i 's|"@dam-plugin/shared": "[^"]*"|"@dam-plugin/shared": "file:///shared"|' package.json \
    && npm install

# Copy source code
COPY server-v1/ ./

# Build TypeScript only (skip openapi-spec as it requires canvas which has arch-specific binaries)
RUN npm run clean && npx tsc

# Production image
FROM node:20-alpine

# Install runtime dependencies for native modules (canvas, sharp), fonts, and curl for health checks
RUN apk add --no-cache \
    curl \
    cairo \
    pango \
    jpeg \
    giflib \
    librsvg \
    pixman \
    fontconfig \
    ttf-dejavu \
    ttf-liberation \
    font-noto \
    && fc-cache -f

# Create app user
RUN addgroup -g 1001 damuser && \
    adduser -D -u 1001 -G damuser damuser

WORKDIR /opt/app

# Copy startup script
COPY start_server.sh ./
RUN chmod +x start_server.sh

# Create server directory
RUN mkdir -p /opt/app/server-v1

WORKDIR /opt/app/server-v1

# Copy shared package into production (runtime dependency)
COPY --from=builder /shared /opt/app/shared

# Copy package files
COPY server-v1/package*.json ./

# Install build dependencies for native modules, install deps, then remove build deps
# Override @dam-plugin/shared to local file path to avoid npm registry lookup
RUN apk add --no-cache --virtual .build-deps \
    python3 \
    make \
    g++ \
    cairo-dev \
    pango-dev \
    jpeg-dev \
    giflib-dev \
    librsvg-dev \
    pixman-dev \
    && sed -i 's|"@dam-plugin/shared": "[^"]*"|"@dam-plugin/shared": "file:///opt/app/shared"|' package.json \
    && npm install --omit=dev \
    && npm cache clean --force \
    && apk del .build-deps

# Copy built application from builder
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/public ./public

# Set ownership
RUN chown -R damuser:damuser /opt/app

# Switch to non-root user
USER damuser

# Environment variables
ENV PORT=3000 \
    HOST=0.0.0.0 \
    NODE_ENV=production

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start server
CMD ["/opt/app/start_server.sh"]
