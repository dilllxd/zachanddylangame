FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force && mkdir /data && chown node:node /data
COPY server.mjs accounts.mjs ./
USER node
EXPOSE 3000
CMD ["node", "server.mjs"]
