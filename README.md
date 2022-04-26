# docker-r
A repository for R containers, with the goal of providing multi-architecture (ARM64 and AMD64) images.

## Image Build
The purpose of this repository is to create R containers that are build-able across multiple
architectures (primary targets are ARM64 and AMD64). While it is possible to perform multi-arch
builds on a single Docker Desktop instance using `buildx` and emulation, the process is at best slow
and and worst buggy, with some steps failing under emulation but working correctly on native 
architecture.  We therefore recommend using `buildx` to perform a multi-node build, where 
the ARM64 image is built on an ARM64 host, and the AMD64 image is build on an AMD64 host. 
The images are then bundled by `buildx` in a Docker manifest list.  When pushed to a registry and deployed,
the Docker client will automatically execute the image tha matches its native architecture.

### Setting up buildx for multi-node build

On ARM host (reverse ARM64 and AMD64 specifications if running from AMD64 host):
```
docker buildx create --name distributed_builder --node distributed_builder_arm64 --platform linux/arm64  --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10000000 --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=10000000

ssh-keygen -t rsa -b 4096 -C "YOUR_EMAIL"
ssh-copy-id REMOTE_USER@REMOTE_HOST

docker buildx create --name distributed_builder --append --node distributed_builder_amd64 --platform linux/amd64 ssh://REMOTE_USER@REMOTE_HOST --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10000000 --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=10000000

docker buildx ls

docker buildx use distributed_builder

docker buildx inspect --bootstrap

docker buildx ls
```

### Building with buildx
```
docker buildx build --platform linux/arm64,linux/amd64 --progress=plain --push --tag MY_TAG .
```

## Running the Image
```
docker \
    run \
    --rm \
    --name r-container \
    -d \
    -v /tmp:/HostData \
    -p 2200:22 \
    -e CONTAINER_USER_USERNAME=test \
    -e CONTAINER_USER_PASSWORD=test \
    hmsccb/docker-r:r-4.2.0-container-1.0.0
```

## Connecting to the running container via SSH
```
ssh test@localhost -p 2200 -Y -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null
```