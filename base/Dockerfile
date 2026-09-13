FROM node:24.15-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code@latest \
    && npm cache clean --force

COPY .claude /root/.claude
WORKDIR /work

CMD ["claude"]
