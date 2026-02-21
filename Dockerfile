FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.12 and system dependencies for audio processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    curl \
    git \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Make python3.12 the default and bootstrap pip via ensurepip
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && python3.12 -m ensurepip --upgrade \
    && python3.12 -m pip install --no-cache-dir --upgrade pip

WORKDIR /app

# Copy requirements first for Docker layer caching
COPY backend/requirements.txt /app/backend/requirements.txt

# Install PyTorch with CUDA 12.4 support (large download, cache this layer)
RUN pip install --no-cache-dir \
    "torch>=2.1.0" --index-url https://download.pytorch.org/whl/cu124

# Install remaining Python dependencies
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Install qwen-tts from git (not available on PyPI with all features)
RUN pip install --no-cache-dir git+https://github.com/QwenLM/Qwen3-TTS.git

# Copy application code
COPY backend/ /app/backend/

# Create data directory
RUN mkdir -p /data/voicebox /data/hf_cache

# Environment variables
ENV HF_HOME=/data/hf_cache
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

EXPOSE 8000

CMD ["python", "-m", "backend.server", "--host", "0.0.0.0", "--port", "8000", "--data-dir", "/data/voicebox"]
