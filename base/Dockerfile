FROM node:24.15-slim

RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code@latest

COPY .claude /root/.claude
WORKDIR /app

CMD ["claude"]
