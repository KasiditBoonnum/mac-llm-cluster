import { useEffect, useState } from "react";
import Sidebar from "./components/sidebar/Sidebar.tsx";
import ChatHeader from "./components/chat/ChatHeader.tsx";
import ChatMessages from "./components/chat/ChatMessages.tsx";
import ChatInput from "./components/chat/ChatInput.tsx";
import type { Message } from "./types/chat";

type ChatItem = { id?: string; title: string };

function App() {

  const [messages, setMessages] = useState<Message[]>([]);
  const [chats, setChats] = useState<ChatItem[]>([]);
  const [activeChat, setActiveChat] = useState<number | null>(null);
  const [token, setToken] = useState<string | null>(typeof localStorage !== 'undefined' ? localStorage.getItem('apiKey') : null);
  const [loggedIn, setLoggedIn] = useState<boolean>(!!token);

  useEffect(() => {
    if (loggedIn) fetchHistory();
  }, [loggedIn]);

  const fetchHistory = async () => {
    try {
      const r = await fetch('/api/history', { headers: { Authorization: token ? `Bearer ${token}` : '' } });
      if (r.ok) {
        const data = await r.json();
        setChats(data.length ? data : []);
      }
    } catch (e) {
      console.error(e);
    }
  };

  const doLogin = async (username: string, password: string) => {
    try {
      const r = await fetch('/api/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username, password }) });
      if (r.ok) {
        const data = await r.json();
        localStorage.setItem('apiKey', data.token);
        setToken(data.token);
        setLoggedIn(true);
        fetchHistory();
        return true;
      }
    } catch (e) {
      console.error(e);
    }
    return false;
  };

  // Send a message: uploads files if any, then call backend /api/chat
  const handleSend = async (text: string, files?: File[], model?: string) => {
    const userMsg: Message = { id: Date.now(), text, sender: "user" };
    setMessages((m) => [...m, userMsg]);

    try {
      const authHeader = token ? { Authorization: `Bearer ${token}` } : {};

      let fileIds: string[] = [];
      if (files && files.length > 0) {
        for (const f of files) {
          const form = new FormData();
          form.append('file', f);
          const r = await fetch('/api/upload', { method: 'POST', body: form, headers: authHeader as any });
          if (r.ok) {
            const d = await r.json();
            fileIds.push(d.id);
          }
        }
      }

      const payload = { model: model || 'qwen2.5', messages: [{ role: 'user', content: text }], fileIds };
      const resp = await fetch('/api/chat', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeader }, body: JSON.stringify(payload) });
      const raw = await resp.text();
      let botText = raw;
      try {
        const data = raw ? JSON.parse(raw) : null;
        botText = data?.choices?.[0]?.message?.content || raw || JSON.stringify(data);
      } catch (e) {
        // ignore
      }

      const botMsg: Message = { id: Date.now() + 1, text: botText, sender: "bot", animate: true };
      setMessages((m) => [...m, botMsg]);
      // refresh history list
      fetchHistory();
    } catch (err) {
      const errMsg: Message = { id: Date.now() + 2, text: "Error: " + String(err), sender: "bot", animate: false };
      setMessages((m) => [...m, errMsg]);
    }
  };

  const handleSelectMessages = async (id?: string | null) => {
    if (!id) {
      // new chat
      setMessages([]);
      setActiveChat(null);
      return;
    }
    try {
      const r = await fetch(`/api/history/${id}`, { headers: { Authorization: token ? `Bearer ${token}` : '' } });
      if (r.ok) {
        const data = await r.json();
        // data is array of messages
        const msgs: Message[] = data.map((m: any) => ({ id: m.id || Date.now(), text: m.text || m, sender: m.sender || 'bot', animate: false }));
        setMessages(msgs);
      }
    } catch (e) {
      console.error(e);
    }
  };

  const handleDeleteRequested = async (index: number) => {
    const chat = chats[index];
    if (!chat?.id) {
      // local-only
      setChats((prev) => prev.filter((_, i) => i !== index));
      return;
    }
    try {
      const r = await fetch(`/api/history/${chat.id}`, { method: 'DELETE', headers: { Authorization: token ? `Bearer ${token}` : '' } });
      if (r.ok) {
        setChats((prev) => prev.filter((_, i) => i !== index));
        setMessages([]);
        setActiveChat(null);
      }
    } catch (e) {
      console.error(e);
    }
  };

  // Simple login UI overlay
  if (!loggedIn) {
    return (
      <div className="flex items-center justify-center h-screen w-screen bg-gray-50">
        <div className="bg-white p-8 rounded shadow-lg w-[420px]">
          <h2 className="text-2xl font-bold mb-4">Login</h2>
          <LoginForm onSubmit={async (u, p) => { const ok = await doLogin(u, p); if (!ok) alert('Login failed'); }} />
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen w-screen overflow-hidden">
      <Sidebar onSelectMessages={handleSelectMessages} chats={chats} onDeleteRequested={handleDeleteRequested} activeChat={activeChat} setActiveChat={setActiveChat} />

      <div className="flex flex-col flex-1 h-screen bg-[#f4f4f4] min-w-0">
        <div className="flex-none">
          <ChatHeader onDeleteCurrent={() => {
            if (activeChat !== null) handleDeleteRequested(activeChat);
          }} />
        </div>

        <div className="flex-1 min-h-0">
          <ChatMessages messages={messages} />
        </div>

        <div className="flex-none">
          <ChatInput onSend={handleSend} />
        </div>
      </div>
    </div>
  );
}

function LoginForm({ onSubmit }: { onSubmit: (u: string, p: string) => void }) {
  const [u, setU] = useState('admin');
  const [p, setP] = useState('admin');
  return (
    <form onSubmit={(e) => { e.preventDefault(); onSubmit(u, p); }}>
      <label className="block mb-2">Username</label>
      <input className="w-full p-2 mb-4 border" value={u} onChange={(e) => setU(e.target.value)} />
      <label className="block mb-2">Password</label>
      <input type="password" className="w-full p-2 mb-4 border" value={p} onChange={(e) => setP(e.target.value)} />
      <div className="flex justify-end">
        <button className="bg-[#006C68] text-white px-4 py-2 rounded">Login</button>
      </div>
    </form>
  );
}

export default App;
