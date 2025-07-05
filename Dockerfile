# Multi-stage Dockerfile for Twitter OAuth Backend

# Stage 1: Build dependencies
FROM node:18-alpine AS dependencies

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for potential build steps)
RUN npm ci --include=dev && npm cache clean --force

# Stage 2: Production image
FROM node:18-alpine AS production

# Install security updates and curl for health checks
RUN apk update && apk upgrade && apk add --no-cache curl dumb-init

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application source code
COPY --chown=nodejs:nodejs . .

# Remove unnecessary files
RUN rm -rf \
    .git \
    .github \
    .vscode \
    *.md \
    test-*.sh \
    server-*.js \
    docker-compose*.yml \
    Dockerfile* \
    .dockerignore

# Switch to non-root user
USER nodejs

# Expose the ports the app runs on (HTTP and HTTPS)
EXPOSE 3001 3443

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]
