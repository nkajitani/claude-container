import os
import json
import urllib.request
import urllib.error
import sys

def get_available_model(api_key):
    """
    現在このAPIキーで利用可能なモデルのリストを取得し、
    最初に見つかったClaudeモデル名を返します。
    """
    url = "https://api.anthropic.com/v1/models"
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01"
    }
    req = urllib.request.Request(url, headers=headers)
    try:
        print("[Step 1] 利用可能なモデルを確認中...")
        with urllib.request.urlopen(req) as res:
            data = json.loads(res.read().decode("utf-8"))
            # 'claude' で始まるモデルを抽出
            models = [m["id"] for m in data.get("data", []) if "claude" in m["id"]]
            if not models:
                return None
            
            # Sonnet系があれば優先、なければ最初に見つかったものを選択
            sonnet_models = [m for m in models if "sonnet" in m]
            selected = sonnet_models[0] if sonnet_models else models[0]
            return selected
    except Exception as e:
        print(f"[Error] モデルリストの取得に失敗しました: {e}")
        return None

def call_claude_api(api_key, model_name, messages):
    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
    data = {
        "model": model_name,
        "max_tokens": 512,
        "messages": messages
    }
    
    req = urllib.request.Request(
        url, 
        data=json.dumps(data).encode("utf-8"), 
        headers=headers
    )
    
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"\n[Error] API call failed ({model_name}): {e.code}")
        print(e.read().decode('utf-8'))
        return None

def main():
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable is not set.")
        sys.exit(1)

    # 1. 動的にモデルを取得
    model_name = get_available_model(api_key)
    if not model_name:
        print("利用可能なClaudeモデルが見つかりませんでした。")
        print("APIコンソールの Settings > Workbench > Models で有効化されているか確認してください。")
        return

    print(f"[Step 2] 使用モデル: {model_name}")

    messages = []
    user_prompt = "今日の晩ご飯はカレーを予定している。隠し味を教えて。簡潔に。"

    print("\n" + "="*60)
    print(" Claude API Context Accumulation Tracker ")
    print("="*60)
    print(f"{'Turn':<5} | {'Input (Accumulated)':<20} | {'Output':<10}")
    print("-" * 60)

    for i in range(1, 4):
        messages.append({"role": "user", "content": user_prompt})
        
        result = call_claude_api(api_key, model_name, messages)
        if not result:
            break
            
        usage = result["usage"]
        input_tokens = usage["input_tokens"]
        output_tokens = usage["output_tokens"]
        
        print(f"{i:<5} | {input_tokens:<20} | {output_tokens:<10}")
        
        # 履歴に回答を追加（これが次回のターンの '再読み込み量' になる）
        messages.append({"role": "assistant", "content": result["content"][0]["text"]})

    print("-" * 60)
    print("検証完了。\n")

if __name__ == "__main__":
    main()
