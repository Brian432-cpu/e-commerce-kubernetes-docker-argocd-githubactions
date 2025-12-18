# syntax=docker/dockerfile:1

ARG NODE_VERSION=20.11.1

################################################################################
# Base image
FROM node:${NODE_VERSION}-alpine AS base
WORKDIR /usr/src/app

# Install libc6-compat for some Node packages
RUN apk add --no-cache libc6-compat

################################################################################
# Dependencies stage (production only)
FROM base AS deps
COPY package.json package-lock.json ./

# Install only production dependencies
RUN npm ci --omit=dev

################################################################################
# Build stage (requires devDependencies)
FROM base AS build
COPY package.json package-lock.json ./

# Install all dependencies including devDependencies
RUN npm ci

# Copy source code
COPY . .

# Optional: pass build-time environment variables (for CI/CD)
# ARG BETTER_AUTH_SECRET
# ARG BETTER_AUTH_URL
# ENV BETTER_AUTH_SECRET=${BETTER_AUTH_SECRET}
# ENV BETTER_AUTH_URL=${BETTER_AUTH_URL}

# Build the Next.js app
RUN npm run build

################################################################################
# Runtime stage (minimal)
FROM base AS final
WORKDIR /usr/src/app

# Set production environment
ENV NODE_ENV=production

# Use non-root user
USER node

# Copy only necessary files from previous stages
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/.next ./.next
COPY --from=build /usr/src/app/public ./public
COPY --from=build /usr/src/app/package.json ./package.json

# Expose application port
EXPOSE 3000

# Start the app
CMD ["npm", "start"]
