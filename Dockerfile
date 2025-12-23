# syntax=docker/dockerfile:1
ARG NODE_VERSION=20.11.1

################################################################################
# 1. Base image
FROM node:${NODE_VERSION}-alpine AS base
WORKDIR /usr/src/app

################################################################################
# 2. Install dependencies
FROM base AS deps
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

################################################################################
# 3. Build stage
FROM base AS build
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN npm ci
COPY . .

# Dummy URL for build-time (Required for Next.js build)
ARG DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"
ENV DATABASE_URL=${DATABASE_URL}
# Optimization: Ensures Next.js builds for minimal production output
ENV NEXT_PRIVATE_STANDALONE_BUILD=true

RUN npm run build

################################################################################
# 4. Runtime stage (Final)
FROM base AS final
ENV NODE_ENV=production
WORKDIR /usr/src/app

# --- PERMISSION FIX START ---
# Create the .next folder as root so we can set permissions
RUN mkdir -p .next/cache/images && chown -R node:node /usr/src/app
# --- PERMISSION FIX END ---

# Copy necessary files from build stage
# We use --chown=node:node to ensure the app can write to its own folders
COPY --from=deps --chown=node:node /usr/src/app/node_modules ./node_modules
COPY --from=build --chown=node:node /usr/src/app/.next ./.next
COPY --from=build --chown=node:node /usr/src/app/public ./public
COPY --from=build --chown=node:node /usr/src/app/package.json ./package.json

# Switch to non-root user for security
USER node

EXPOSE 3000
ENV PORT 3000

# Start the application
CMD ["npm", "start"]
