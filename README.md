-- Build container
podman buildx build -t debian-image -f Containerfile .

-- Create container
podman create --name debian-container -h trixie --shm-size=4g --memory=0 --memory-swap=0 --cpus=0 --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -p 33890:3389 -p 2222:22 -p 30000:3000 debian-image
