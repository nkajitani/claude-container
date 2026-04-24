
---
# Claude Code Base

Claude Code を Docker で運用するための汎用基盤です。

## 概要

SIer スタイルのフェーズ管理（要件定義 → 設計 → 製造 → テスト）をエージェント構成に落とし込み、
AI が自律的に開発を進める仕組みを提供します。
ワークフローの詳細は `.claude/CLAUDE.md` を参照してください。


## 留意事項
1. .envを作成し、ANTHROPIC_API_KEYを設定してください。
2. バインドマウントしたいディレクトリをcompose.ymlに記載ください。
