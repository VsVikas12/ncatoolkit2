# Dockerfile2 - Optimized for Render Free Tier
FROM python:3.9-slim

# Install system dependencies using pre-built packages instead of building from source
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libavcodec-extra \
    libavformat-dev \
    libavfilter-dev \
    libavdevice-dev \
    libfreetype6-dev \
    libfontconfig1 \
    fonts-liberation \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Copy font files (if needed)
COPY ./fonts /usr/share/fonts/custom

# Rebuild the font cache
RUN fc-cache -f -v

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir openai-whisper jsonschema

# Create directories
RUN mkdir -p /app/storage /app/whisper_cache

# Create non-root user
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Copy the application code
COPY . .

# Expose the port
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV WHISPER_CACHE_DIR="/app/whisper_cache"
ENV LOCAL_STORAGE_PATH="/app/storage"

# Create startup script
RUN echo '#!/bin/bash\n\
# Download smaller whisper model at runtime to avoid build memory issues\n\
python -c "import os, whisper; print(\"Loading whisper model...\"); whisper.load_model(\"tiny\")"\n\
\n\
# Start the application\n\
gunicorn --bind 0.0.0.0:8080 \
    --workers ${GUNICORN_WORKERS:-1} \
    --timeout ${GUNICORN_TIMEOUT:-300} \
    --worker-class sync \
    --keep-alive 80 \
    --log-level info \
    app:app' > /app/run_gunicorn.sh && \
    chmod +x /app/run_gunicorn.sh

# Run the application
CMD ["/app/run_gunicorn.sh"]
