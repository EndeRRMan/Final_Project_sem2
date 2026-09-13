FROM node:16.20.2-bullseye AS builder

WORKDIR /app
COPY package.json package-lock.json ./
# Styles are CSS; the legacy optional node-sass package is not needed.
RUN npm ci --omit=optional --no-audit --no-fund
COPY . .
RUN npm run build && test -f dist/frontend/index.html

FROM nginx:1.28.0-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist/frontend/ /usr/share/nginx/html/
EXPOSE 80
