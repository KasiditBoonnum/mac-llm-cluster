import { useState } from "react";
import NewChatButton from "./NewChatButton";
import ChatHistory from "./ChatHistory";
import UserProfile from "./UserProfile";
import LOGO from "../../assets/OCS_LLM.png";

type Props = {
  onSelectMessages: (which: 0 | 1 | 2 | 3) => void;
};

export default function Sidebar({ onSelectMessages }: Props) {
  const [activeChat, setActiveChat] = useState<number | null>(0);

  const handleNew = () => {
    onSelectMessages(0);
    setActiveChat(null);
  };

  return (
    <div className="w-[300px] h-screen bg-[#2f3337] text-white flex flex-col justify-between p-5">
      
      {/* ส่วนบน: Logo และปุ่ม New Chat */}
      <div className="flex-none">
        <div className="flex items-center gap-4">
          <img src={LOGO} className="w-20 h-20 rounded" alt="Logo" />
          <div className="flex flex-col items-start">
            <h1 className="text-5xl font-bold !my-0">KU</h1>
            <h2 className="text-4xl font-bold">ChatBot</h2>
          </div>
        </div>
        <div className="h-3 bg-[#b2bb1c] mt-2" />
        <NewChatButton onNew={handleNew} />
        <hr className="my-6 border-gray-500" />
      </div>

      {/* ส่วนกลาง: Chat History (กินพื้นที่ที่เหลือทั้งหมด และ Scroll ตรงนี้) */}
      <div className="flex-1 min-h-0 w-full min-w-0 overflow-hidden">
        <ChatHistory
          onSelectMessages={onSelectMessages}
          activeChat={activeChat}
          setActiveChat={setActiveChat}
        />
      </div>

      {/* ส่วนล่าง: User Profile */}
      <div className="flex-none">
        <hr className="my-6 border-gray-500" />
        <UserProfile />
      </div>

    </div>
  );
}