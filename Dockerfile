FROM node:20-alpine

# Install system deps for Prisma
RUN apk add --no-cache openssl

WORKDIR /app

# Copy package manifests + prisma schema first (better caching)
COPY package*.json ./
COPY prisma ./prisma

# Install ALL deps (including dev — needed for tsx)
RUN npm install --include=dev

# Generate Prisma Client
RUN npx prisma generate

# Copy rest of the source
COPY . .

# Ensure tsx binary path is on PATH
ENV PATH="/app/node_modules/.bin:${PATH}"

# Start worker
CMD ["npx", "tsx", "workers/sender.worker.ts"]
