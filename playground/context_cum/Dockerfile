FROM python:alpine3.22

WORKDIR /work

RUN apk add --no-cache curl-dev

# Pythonの動作設定（バッファリング無効化など）
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# 実行コマンドのデフォルト設定
CMD ["python", "context_cum.py"]
