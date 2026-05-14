#!/bin/bash
set -e

echo "=== 安装 Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh

echo "=== 启动 Ollama 服务 ==="
ollama serve &
sleep 5

echo "=== 下载模型（约4.5GB，需要5-10分钟）==="
ollama pull qwen2.5-coder:7b-q4_K_M

echo "=== 安装 Python 依赖 ==="
pip install fastapi uvicorn httpx

echo "=== 创建 API 网关 ==="
cat > /workspaces/$(basename $PWD)/api_gateway.py << 'EOF'
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import httpx
import time
import uvicorn
from threading import Thread

app = FastAPI()

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    try:
        data = await request.json()
        messages = data.get("messages", [])
        
        # 提取最后一条用户消息
        if messages and messages[-1]["role"] == "user":
            prompt = messages[-1]["content"]
        else:
            prompt = " ".join([m["content"] for m in messages if m["role"] == "user"])
        
        # 调用 Ollama
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "qwen2.5-coder:7b-q4_K_M",
                    "prompt": prompt,
                    "stream": False,
                    "options": {"num_predict": 2048}
                }
            )
            result = response.json()
        
        # 返回 OpenAI 格式
        return JSONResponse({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": result.get("response", "")
                }
            }]
        })
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

@app.get("/health")
async def health():
    return {"status": "ok"}

def run():
    uvicorn.run(app, host="0.0.0.0", port=8080)

if __name__ == "__main__":
    run()
EOF

echo "=== 启动 API 网关 ==="
python /workspaces/$(basename $PWD)/api_gateway.py &

echo "=== 等待服务启动 ==="
sleep 3

echo "=== 获取公网地址 ==="
echo "请在 Codespaces 的 'Ports' 标签页中，找到 8080 端口"
echo "右键 -> 'Port Visibility' -> 选择 'Public'"
echo "然后复制显示的地址（例如：https://xxx-8080.github.dev）"
echo ""
echo "最终 API 地址为：复制的地址 + /v1"
echo "例如：https://xxx-8080.github.dev/v1"
echo ""
echo "模型名称：qwen2.5-coder:7b"
echo "API Key：任意填写"
