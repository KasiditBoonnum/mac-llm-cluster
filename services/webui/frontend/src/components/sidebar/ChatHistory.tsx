import React from "react";
import type { Dispatch, SetStateAction } from "react";

type Props = {
  onSelectMessages: (id?: string | null) => void;
  activeChat: number | null;
  setActiveChat: Dispatch<SetStateAction<number | null>>;
  // Called when a chat is deleted in-memory. Receives the deleted index.
  onDeleteRequested?: (index: number) => void;
  chats: { id?: string; title: string }[];
};

export default function ChatHistory({ onSelectMessages, activeChat, setActiveChat, onDeleteRequested, chats }: Props) {

  const handleDelete = (e: React.MouseEvent, index: number) => {
    e.stopPropagation();
    onDeleteRequested?.(index);
  };

  return (
    <div className="flex flex-col h-full w-full min-w-0 overflow-y-auto">

      <h2
        className="
          !text-lg
          font-bold
          !mb-5
          flex
          items-start
        "
      >
        เมื่อเร็วๆนี้
      </h2>

      {chats.map((chat, index) => (

        <div key={index} className={`mb-2 ${activeChat === index ? "bg-[#4b5563] rounded-lg" : ""}`}>
          <div
            role="button"
            onClick={() => {
              setActiveChat(index);
              onSelectMessages(chat.id);
            }}
            className={`w-full text-left p-2 transition flex items-center justify-between cursor-pointer`}
          >

            <p className="text-sm text-gray-200 line-clamp-2 break-words whitespace-normal">
              {chat.title}
            </p>

            <button
              onClick={(e) => handleDelete(e, index)}
              className="ml-4 text-red-400 hover:text-red-600"
              aria-label={`ลบแชท ${index}`}
            >
              ลบ
            </button>

          </div>
        </div>

      ))}

    </div>
  );
}