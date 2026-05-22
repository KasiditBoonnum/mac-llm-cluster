import express from "express";

const app = express();
const port = process.env.PORT || 8000;

app.use(express.json());

const LITELLM_URL = process.env.LITELLM_URL || process.env.OLLAMA_BASE_URLS || "http://localhost:11434";
const AUTH_HEADER = process.env.LITELLM_AUTH || "";

app.post("/api/chat", async (req, res) => {
  try {
    const payload = req.body || {};

    // Forward to LiteLLM-compatible endpoint (assumed OpenAI-like /v1/chat/completions)
    const target = `${LITELLM_URL.replace(/;.*$/, "")}/v1/chat/completions`;

    const headers = { "Content-Type": "application/json" };
    if (AUTH_HEADER) headers["Authorization"] = AUTH_HEADER;

    // Use global fetch (Node 18+ provides fetch). No external dependency required.
    const r = await fetch(target, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    const data = await r.json();
    res.status(r.status).json(data);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, () => {
  console.log(`webui-backend listening on port ${port}, proxy -> ${LITELLM_URL}`);
});
