import express from "express";
import cors from "cors";
import multer from "multer";
import fs from "fs";
import path from "path";
import { v4 as uuidv4 } from "uuid";

const app = express();
const port = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

const LITELLM_URL = process.env.LITELLM_URL || process.env.OLLAMA_BASE_URLS || "http://localhost:8082";
const AUTH_HEADER = process.env.LITELLM_AUTH || "";

// Simple storage
const UPLOAD_DIR = path.join(process.cwd(), "uploads");
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const upload = multer({ dest: UPLOAD_DIR });

// In-memory auth tokens and histories
const tokens = new Map(); // token -> username
const histories = new Map(); // username -> [{ id, title, messages }]

// Simple models list
const MODELS = [
  { name: "qwen2.5", desc: "General purpose Qwen 2.5" },
  { name: "qwen3.6", desc: "High-capacity Qwen 3.6" },
  { name: "phi4", desc: "Low-latency phi4" },
  { name: "deepseek", desc: "DeepSeek coder" },
];

// Map short names to the actual model identifiers expected by the LITELLM/Gateway
const MODEL_ALIASES = {
  "qwen2.5": "qwen2.5:32b-instruct-q4_K_M",
  "deepseek": "deepseek-coder:33b-instruct-q4_K_M",
  "qwen3.6": "exo:Qwen3.6-35B-A3B-8bit",
  "phi4": "phi4:latest",
};

app.post("/api/login", (req, res) => {
  const { username, password } = req.body || {};
  if (username === "admin" && password === "admin") {
    const token = uuidv4();
    tokens.set(token, username);
    if (!histories.has(username)) histories.set(username, []);
    return res.json({ token });
  }
  res.status(401).json({ error: "Invalid credentials" });
});

app.get("/api/models", (req, res) => {
  (async () => {
    try {
      const target = `${LITELLM_URL.replace(/;.*$/, "")}/v1/models`;
      const r = await fetch(target);
      if (r.ok) {
        const data = await r.json();
        // data may be { object: 'list', data: [ { id, object, ... } ] }
        const list = (data?.data || []).map((m) => {
          // find a short alias if available
          const alias = Object.keys(MODEL_ALIASES).find((k) => MODEL_ALIASES[k].toLowerCase() === (m.id || '').toLowerCase());
          return { name: alias || m.id, id: m.id, desc: m.description || '' };
        });
        return res.json(list);
      }
    } catch (err) {
      console.warn('Could not fetch models from LITELLM_URL', err);
    }

    // fallback to internal list
    res.json(MODELS.map((m) => ({ name: m.name, id: MODEL_ALIASES[m.name] || m.name, desc: m.desc })));
  })();
});

app.post("/api/upload", upload.single("file"), (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "No file uploaded" });
    const { originalname, filename } = req.file;
    if (!originalname.toLowerCase().endsWith(".pdf")) {
      // remove file
      fs.unlinkSync(path.join(UPLOAD_DIR, filename));
      return res.status(400).json({ error: "Only PDF files are allowed" });
    }
    const id = filename;
    const url = `/uploads/${filename}`;
    res.json({ id, url, name: originalname });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: String(err) });
  }
});

// serve uploads
app.use("/uploads", express.static(UPLOAD_DIR));

// list history
app.get("/api/history", (req, res) => {
  const auth = (req.headers.authorization || "").replace(/^Bearer\s*/, "");
  const user = tokens.get(auth) || "guest";
  const list = (histories.get(user) || []).map((h) => ({ id: h.id, title: h.title }));
  res.json(list);
});

app.get("/api/history/:id", (req, res) => {
  const auth = (req.headers.authorization || "").replace(/^Bearer\s*/, "");
  const user = tokens.get(auth) || "guest";
  const id = req.params.id;
  const hs = histories.get(user) || [];
  const found = hs.find((h) => h.id === id);
  if (!found) return res.status(404).json({ error: "Not found" });
  res.json(found.messages || []);
});

app.delete("/api/history/:id", (req, res) => {
  const auth = (req.headers.authorization || "").replace(/^Bearer\s*/, "");
  const user = tokens.get(auth) || "guest";
  const id = req.params.id;
  const hs = histories.get(user) || [];
  const idx = hs.findIndex((h) => h.id === id);
  if (idx >= 0) {
    hs.splice(idx, 1);
    histories.set(user, hs);
    return res.json({ ok: true });
  }
  res.status(404).json({ error: "Not found" });
});

app.post("/api/chat", async (req, res) => {
  try {
    const payload = req.body || {};
    const model = payload.model || "qwen2.5";
    const messages = payload.messages || [];
    const fileIds = payload.fileIds || [];

    // Build forward payload for LiteLLM/OpenAI-compatible endpoint
    const target = `${LITELLM_URL.replace(/;.*$/, "")}/v1/chat/completions`;

    const headers = { "Content-Type": "application/json" };
    if (AUTH_HEADER) headers["Authorization"] = AUTH_HEADER;

    // If files were uploaded, include a system message listing them (public URLs served by this backend)
    let forwardMessages = [...messages];
    if (fileIds && fileIds.length > 0) {
      const fileUrls = fileIds.map((id) => `${req.protocol}://${req.get("host")}/uploads/${id}`);
      forwardMessages = [
        { role: "system", content: `Attached files: ${fileUrls.join(", ")}` },
        ...forwardMessages,
      ];
    }

    // translate shorthand model names to actual model ids used by the gateway
    const modelId = MODEL_ALIASES[(model || "").toLowerCase()] || model || "qwen2.5";
    const body = { model: modelId, messages: forwardMessages };

    const r = await fetch(target, { method: "POST", headers, body: JSON.stringify(body) });
    const data = await r.json();

    // Save to in-memory history if authenticated
    const auth = (req.headers.authorization || "").replace(/^Bearer\s*/, "");
    const user = tokens.get(auth) || "guest";
    if (!histories.has(user)) histories.set(user, []);
    const hs = histories.get(user);
    // Ensure a chat exists for this session: use today's id or create new
    let chat = hs.length ? hs[hs.length - 1] : null;
    if (!chat || (messages && messages.length && messages[0].role === "user" && messages[0].content)) {
      // Append messages to current chat or create new
      if (!chat) {
        chat = { id: uuidv4(), title: messages[0]?.content?.slice(0, 80) || "New chat", messages: [] };
        hs.push(chat);
      }
      // push user and bot
      chat.messages.push(...messages.map((m) => ({ id: Date.now() + Math.random(), text: m.content || m, sender: m.role === "user" ? "user" : "bot" })));
      const botText = data?.choices?.[0]?.message?.content || JSON.stringify(data);
      chat.messages.push({ id: Date.now() + Math.random() + 1, text: botText, sender: "bot" });
    }

    res.status(r.status).json(data);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, () => {
  console.log(`webui-backend listening on port ${port}, proxy -> ${LITELLM_URL}`);
});
