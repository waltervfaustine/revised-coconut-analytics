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

# Install bundlify package for bundling
RUN npm run bundlify

# Install vendorify package for vendor management
RUN npm run vendorify

# Copy the rest of the source code to the container
COPY . .

# Expose the port on which the application will run
EXPOSE 8082

# Command to run the application
# CMD ["npm", "run", "start"]