# Multi-stage build for production
FROM node:22-alpine AS builder

WORKDIR /frontend

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:22-alpine

WORKDIR /frontend

# Copy built application from builder stage
COPY --from=builder /frontend/build ./build
COPY --from=builder /frontend/package*.json ./

# Install only production dependencies
# RUN npm ci --only=production
RUN npm ci --omit=dev

# Expose port
EXPOSE 80

# Set environment variables for Node server
ENV HOST=0.0.0.0
ENV PORT=80

# Start the application
CMD ["node", "build"]