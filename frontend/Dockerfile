FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine AS runtime

ENV NODE_ENV=production

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/node_modules ./node_modules
COPY app.js package.json package-lock.json ./
COPY views ./views

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD ["node", "-e", "const port = process.env.FRONTEND_PORT || '5000'; fetch(`http://127.0.0.1:${port}/health`).then((res) => process.exit(res.ok ? 0 : 1)).catch(() => process.exit(1));"]

CMD ["node", "app.js"]
