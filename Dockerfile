FROM node:20-bookworm-slim

RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

RUN useradd -m appuser
USER appuser

ENV NODE_ENV=production

EXPOSE 3000

CMD ["node", "app.js"]
