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
FROM node:18-alpine

WORKDIR /frontend

# Copy built application from builder stage
COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json ./

# Install only production dependencies
RUN npm ci --only=production

# Expose port
EXPOSE 80

# Set environment variables for Node server
ENV HOST=0.0.0.0
ENV PORT=80

# Start the application
CMD ["node", "build"]