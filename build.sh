#!/bin/bash

# Docker Hub username
IMAGE_NAME="heapsgo0d/nexis"
IMAGE_TAG="v1.0.8.5"



docker buildx build --platform linux/amd64 -t "${IMAGE_NAME}:${IMAGE_TAG}" --load .

echo "Confirming image creation:"
docker images | grep "${IMAGE_NAME}"

docker push "${IMAGE_NAME}:${IMAGE_TAG}"