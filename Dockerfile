# Multi-stage Dockerfile for AI Test Benchmark System
# Supports JavaScript, Python, and Java testing environments

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up working directory
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Basic utilities
    curl \
    wget \
    git \
    vim \
    tree \
    jq \
    bc \
    # Python dependencies
    python3 \
    python3-pip \
    python3-venv \
    # Node.js (via NodeSource)
    ca-certificates \
    gnupg \
    # Java dependencies
    openjdk-11-jdk \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python testing tools
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir \
    pytest>=7.4.0 \
    pytest-cov>=4.1.0 \
    coverage>=7.3.0 \
    pandas \
    jinja2

# Set up environment variables
ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=development
ENV MAVEN_OPTS="-Xmx1024m"

# Create directory structure
RUN mkdir -p /workspace/ai-test-benchmark/benchmarks/{javascript,python,java} && \
    mkdir -p /workspace/ai-test-benchmark/results/coverage_reports && \
    mkdir -p /workspace/ai-test-benchmark/scripts

# Copy scripts into the container
COPY run_all_tests.sh /workspace/ai-test-benchmark/
COPY generate_coverage_reports.sh /workspace/ai-test-benchmark/
COPY create_project_template.sh /workspace/ai-test-benchmark/

# Make scripts executable
RUN chmod +x /workspace/ai-test-benchmark/*.sh

# Set working directory
WORKDIR /workspace/ai-test-benchmark

# Create a non-root user
RUN useradd -m -s /bin/bash testuser && \
    chown -R testuser:testuser /workspace

USER testuser

# Default command - drop into bash
CMD ["/bin/bash"]
