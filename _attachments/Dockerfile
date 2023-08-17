# Use a slim Node.js image as the base
FROM node:14-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install dependencies and cleanup in a single layer
RUN npm install && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Run the custom command 'npm run install-server'
RUN npm run install-server

# Copy the rest of the source code to the container
COPY . .

# Install bundlify package for bundling
RUN npm install bundlify

# Install vendorify package for vendor management
RUN npm install vendorify