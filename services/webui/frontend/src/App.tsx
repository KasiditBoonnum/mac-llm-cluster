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

  // Handler passed to Sidebar so its controls can set which mock messages are shown
  const handleSelectMessages = (which: 0 | 1 | 2 | 3) => {
    if (which === 0) return setMessages(mockMessages0);
    if (which === 1) return setMessages(mockMessages1);
    if (which === 2) return setMessages(mockMessages2);
    return setMessages(mockMessages3);
  };

  return (
    <div className="flex h-screen w-screen overflow-hidden">
      {/* ฝั่งซ้าย: Sidebar */}
      <Sidebar onSelectMessages={handleSelectMessages} />

      {/* ฝั่งขวา: พื้นที่แชททั้งหมด */}
      <div className="flex flex-col flex-1 h-screen bg-[#f4f4f4] min-w-0">
        {/* หัวแชท - ล็อกความสูงไว้ */}
        <div className="flex-none">
          <ChatHeader />
        </div>

        {/* รายการข้อความ - ให้ยืดเต็มที่ตรงกลาง และยอมหดตัวเพื่อตัด Scrollbar */}
        <div className="flex-1 min-h-0">
          <ChatMessages messages={messages} />
        </div>

        {/* ช่องกรอกข้อความ - ล็อกให้อยู่ล่างสุดเสมอ */}
        <div className="flex-none">
          <ChatInput />
        </div>
      </div>
    </div>
  );
}

export default App;
