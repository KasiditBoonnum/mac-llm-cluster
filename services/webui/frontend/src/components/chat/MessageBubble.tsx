type Props = {
  text: string;
  sender: "user" | "bot";
};

export default function MessageBubble({
  text,
  sender,
}: Props) {

  const isUser = sender === "user";

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
          px-6
          py-4
          rounded-3xl
          text-sm
          shadow-sm

          ${
            isUser
              ? "bg-[#03A96B] text-white"
              : "bg-[#e9e9e9] text-black"
          }
        `}
      >
        {text}
      </div>
    </div>
  );
}