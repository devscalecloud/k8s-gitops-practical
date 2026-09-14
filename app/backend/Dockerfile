# --- Build stage ---
FROM node:20-slim AS build
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# --- Runtime stage ---
FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json* ./
RUN npm install --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist

RUN groupadd --system appgroup && useradd --system --gid appgroup appuser
USER appuser

EXPOSE 4000

CMD ["node", "dist/server.js"]
