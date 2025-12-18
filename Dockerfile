# syntax=docker/dockerfile:1

ARG NODE_VERSION=20.11.1

################################################################################
# Base image
FROM node:${NODE_VERSION}-alpine AS base

WORKDIR /usr/src/app

################################################################################
# Install dependencies (production)
FROM base AS deps

RUN apk add --no-cache libc6-compat

COPY package.json package-lock.json ./

RUN npm ci --omit=dev

################################################################################
# Build stage
FROM base AS build

RUN apk add --no-cache libc6-compat

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# ⚠️ Use a dummy DATABASE_URL for build-time
ARG DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"
ENV DATABASE_URL=${DATABASE_URL}

# Prevent Next.js from accessing real secrets at build time
RUN npm run build

################################################################################
# Runtime stage (minimal)
FROM base AS final

ENV NODE_ENV=production

# Create non-root user
USER node

WORKDIR /usr/src/app

# Copy dependencies and built app
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/.next ./.next
COPY --from=build /usr/src/app/public ./public
COPY --from=build /usr/src/app/package.json ./package.json

EXPOSE 3000

# Real secrets will be injected via Kubernetes at runtime
CMD ["npm", "start"]
