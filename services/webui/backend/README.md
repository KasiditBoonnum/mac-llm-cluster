Local backend proxy for webui to forward requests to LiteLLM.

Usage (development):

```bash
cd services/webui/backend
npm install
LITELLM_URL="http://llm-01.local:11434" npm start
```

The backend exposes `POST /api/chat` and forwards to `${LITELLM_URL}/v1/chat/completions`.
Here you make backend
