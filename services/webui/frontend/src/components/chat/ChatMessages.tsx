import MessageBubble from "./MessageBubble";
import WelcomeScreen from "./WelcomeScreen";
import type { Message } from "../../types/chat";

type Props = {
  messages: Message[];
};

export default function ChatMessages({ messages }: Props) {

  const hasMessages = messages.length > 0;

  return (
    <div
      className="
        overflow-y-auto
        px-8
        py-6
        h-full
      "
    >

      {!hasMessages ? (
        <WelcomeScreen />
      ) : (
        messages.map((message) => (
          <MessageBubble
            key={message.id}
            text={message.text}
            sender={message.sender}
          />
        ))
      )}

    </div>
  );
}