# -------- Stage 1: Build --------
FROM node:20-bookworm-slim AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .


# -------- Stage 2: Distroless Runtime --------
FROM gcr.io/distroless/nodejs20-debian12

WORKDIR /app

COPY --from=builder /app /app

ENV NODE_ENV=production

USER nonroot

EXPOSE 3000

CMD ["app.js"]
