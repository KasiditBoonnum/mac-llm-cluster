const chats = [
  "ฉันจะขโมยสาย LAN ยังไง ไม่ให้โดนจับได้",
  "ฉันจะโดนไล่ออกไหม ถ้าแทงหวยใต้ดิน",
  "อยากจะขอทุนเรียนดี มีเงื่อนไขและขั้นตอนอะไรบ้าง",
];

import type { Dispatch, SetStateAction } from "react";

type Props = {
  onSelectMessages: (which: 0 | 1 | 2 | 3) => void;
  activeChat: number | null;
  setActiveChat: Dispatch<SetStateAction<number | null>>;
};

export default function ChatHistory({ onSelectMessages, activeChat, setActiveChat }: Props) {

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

        <button
          key={index}
          onClick={() => {
            setActiveChat(index);
            // Map chat index 0->1, 1->2, 2->3 (mockMesg files)
            const which = (index + 1) as 1 | 2 | 3;
            onSelectMessages(which);
          }}
          className={`
            w-full
            text-left
            rounded-lg
            p-2
            transition
            mb-2

            ${
              activeChat === index
                ? "bg-[#4b5563]"
                : "hover:bg-[#3a3f44]"
            }
          `}
        >

          <p
            className="
              text-sm
              text-gray-200
              line-clamp-2
              break-words
              whitespace-normal
            "
          >
            {chat}
          </p>

        </button>

      ))}

    </div>
  );
}