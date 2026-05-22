type Props = {
  onNew: () => void;
};

export default function NewChatButton({ onNew }: Props) {
  return (
    <button onClick={onNew}
      className="
      bg-white
      text-black
      w-2/3
      py-3
      rounded-full
      text-xl
      font-bold
      mt-8
      hover:scale-[1.02]
      transition
    "
    >
      + New Chat
    </button>
  );
}