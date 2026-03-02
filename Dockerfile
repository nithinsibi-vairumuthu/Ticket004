# ---------- Base Image ----------
FROM node:20-bookworm-slim

# Set environment
ENV NODE_ENV=production

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm install --omit=dev

# Copy remaining app files
COPY . .

# Create non-root user
RUN useradd -m appuser && chown -R appuser:appuser /app

USER appuser

EXPOSE 3000

CMD ["node", "app.js"]
