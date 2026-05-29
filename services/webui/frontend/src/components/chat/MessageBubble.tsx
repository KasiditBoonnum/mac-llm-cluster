import { useEffect, useState } from "react";
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import TYPING_GIF from "../../assets/image/loading.gif";

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
        <div className="whitespace-pre-wrap break-words text-left">
          {(!isUser && animate && (!visible || visible.length === 0)) ? (
            <div className="w-[120px] h-[40px]">
              <img src={TYPING_GIF} alt="typing" className="w-full h-full object-contain" />
            </div>
          ) : (
            <ReactMarkdown remarkPlugins={[remarkGfm]} components={{
              code({node, inline, className, children, ...props}){
                return !inline ? (
                  <pre className="bg-gray-800 text-white rounded p-2 overflow-auto"><code {...props}>{String(children)}</code></pre>
                ) : (
                  <code className="bg-gray-200 rounded px-1">{children}</code>
                )
              }
            }}>{visible}</ReactMarkdown>
          )}
        </div>
      </div>
    </div>
  );
}