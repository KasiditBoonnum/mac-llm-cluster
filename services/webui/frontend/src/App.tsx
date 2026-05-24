import { useState } from "react";
import Sidebar from "./components/sidebar/Sidebar.tsx";
import ChatHeader from "./components/chat/ChatHeader.tsx";
import ChatMessages from "./components/chat/ChatMessages.tsx";
import ChatInput from "./components/chat/ChatInput.tsx";
import type { Message } from "./types/chat";
import { mockMessages as mockMessages0 } from "./data/mockMesg0.ts";
import { mockMessages as mockMessages1 } from "./data/mockMesg1.ts";
import { mockMessages as mockMessages2 } from "./data/mockMesg2.ts";
import { mockMessages as mockMessages3 } from "./data/mockMesg3.ts";

function App() {

  const [messages, setMessages] = useState<Message[]>(mockMessages0);
  const initialChats = [
    "ฉันจะขโมยสาย LAN ยังไง ไม่ให้โดนจับได้",
    "ฉันจะโดนไล่ออกไหม ถ้าแทงหวยใต้ดิน",
    "อยากจะขอทุนเรียนดี มีเงื่อนไขและขั้นตอนอะไรบ้าง",
  ];

  const [chats, setChats] = useState<string[]>(initialChats);
  const [activeChat, setActiveChat] = useState<number | null>(null);

  // Send a message to backend and append response
  const handleSend = async (text: string) => {
    const userMsg: Message = { id: Date.now(), text, sender: "user" };
    setMessages((m) => [...m, userMsg]);

    try {
      const resp = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "qwen2.5", messages: [{ role: "user", content: text }] }),
      });
      const data = await resp.json();
      // attempt to read assistant content (OpenAI-like)
      const botText = data?.choices?.[0]?.message?.content || JSON.stringify(data);
      const botMsg: Message = { id: Date.now() + 1, text: botText, sender: "bot" };
      setMessages((m) => [...m, botMsg]);
    } catch (err) {
      const errMsg: Message = { id: Date.now() + 2, text: "Error: " + String(err), sender: "bot" };
      setMessages((m) => [...m, errMsg]);
    }
  };

  // Handler passed to Sidebar so its controls can set which mock messages are shown
  const handleSelectMessages = (which: 0 | 1 | 2 | 3) => {
    if (which === 0) return setMessages(mockMessages0);
    if (which === 1) return setMessages(mockMessages1);
    if (which === 2) return setMessages(mockMessages2);
    return setMessages(mockMessages3);
  };

  const handleDeleteRequested = (index: number) => {
    const wasActive = activeChat === index;
    setChats((prev) => prev.filter((_, i) => i !== index));
    if (wasActive) {
      setMessages([]);
      setActiveChat(null);
    }
  };

  return (
    <div className="flex h-screen w-screen overflow-hidden">
      {/* ฝั่งซ้าย: Sidebar */}
      <Sidebar onSelectMessages={handleSelectMessages} chats={chats} onDeleteRequested={handleDeleteRequested} activeChat={activeChat} setActiveChat={setActiveChat} />

      {/* ฝั่งขวา: พื้นที่แชททั้งหมด */}
      <div className="flex flex-col flex-1 h-screen bg-[#f4f4f4] min-w-0">
        {/* หัวแชท - ล็อกความสูงไว้ */}
        <div className="flex-none">
          <ChatHeader onDeleteCurrent={() => {
            if (activeChat !== null) handleDeleteRequested(activeChat);
          }} />
        </div>

        {/* รายการข้อความ - ให้ยืดเต็มที่ตรงกลาง และยอมหดตัวเพื่อตัด Scrollbar */}
        <div className="flex-1 min-h-0">
          <ChatMessages messages={messages} />
        </div>

        {/* ช่องกรอกข้อความ - ล็อกให้อยู่ล่างสุดเสมอ */}
        <div className="flex-none">
          <ChatInput onSend={handleSend} />
        </div>
      </div>
    </div>
  );
}

export default App;
