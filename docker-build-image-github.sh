#!/bin/bash

# Run 'git pull' to update the repository
git pull

# Copy the 'config.json' file
sudo cp /home/serveruser/coconut-implementation/coconut-config/config.json .

# Build the Docker containers using docker-compose
sudo docker-compose build

sudo docker-compose up