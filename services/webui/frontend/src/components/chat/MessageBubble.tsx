import { useEffect, useState } from "react";

type Props = {
  text: string;
  sender: "user" | "bot";
  animate?: boolean;
};

export default function MessageBubble({
  text,
  sender,
  animate,
}: Props) {

  const isUser = sender === "user";
  const [visible, setVisible] = useState<string>(isUser ? text : "");

  useEffect(() => {
    let mounted = true;
    if (!animate || isUser) {
      setVisible(text);
      return;
    }

    setVisible("");
    const speed = 10; // ms per char
    let i = 0;
    const timer = setInterval(() => {
      if (!mounted) return;
      i++;
      setVisible(text.slice(0, i));
      if (i >= text.length) {
        clearInterval(timer);
      }
    }, speed);

    return () => { mounted = false; clearInterval(timer); };
  }, [text, animate, isUser]);

  return (
    <div
      className={`
        flex
        mb-4
        ${isUser ? "justify-end" : "justify-start"}
      `}
    >
      <div
        className={`
          max-w-[60%]
          px-4
          py-2
          rounded-3xl
          text-lg
          shadow-sm

          ${
            isUser
              ? "bg-[#03A96B] text-white"
              : "bg-[#e9e9e9] text-black"
          }
        `}
      >
        <div className="whitespace-pre-wrap break-words text-left">{visible}</div>
      </div>
    </div>
  );
}