# Use an official Node.js runtime as a parent image
FROM node:14-alpine

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY package*.json ./

# Install project dependencies
# RUN npm install --no-optional --unsafe-perm

# RUN npm install && \
#     npm cache clean --force && \
#     rm -rf /tmp/*

RUN npm install && 

RUN npm cache clean --force

# Copy the rest of the application code to the container
COPY . .

# Build and bundle the CoffeeScript files
# RUN npm run bundlify

# Expose the port your app runs on
# EXPOSE 8095

# Default command to run the application
# CMD ["npm", "run", "start"]
