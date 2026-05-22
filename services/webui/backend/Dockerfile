FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
# Use npm install because package-lock.json may not be present in this repo
RUN npm install --production --silent
COPY . .
EXPOSE 8000
CMD ["node", "server.js"]
