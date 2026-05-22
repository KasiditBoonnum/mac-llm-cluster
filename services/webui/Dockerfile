### Multi-stage build: build frontend and serve with nginx
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies and build
COPY frontend/package*.json ./
RUN npm ci --silent
COPY frontend/ ./
RUN npm run build

FROM nginx:stable-alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
