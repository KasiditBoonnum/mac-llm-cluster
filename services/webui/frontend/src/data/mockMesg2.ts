import type { Message } from "../types/chat";

export const mockMessages: Message[] = [
  {
    id: 1,
    text: "ฉันจะโดนไล่ออกไหม ถ้าแทงหวยใต้ดิน",
    sender: "user",
  },

  {
    id: 2,
    text: "แน่นอนครับ การแทงหวยใต้ดินเป็นสิ่งผิดกฎหมาย และอาจส่งผลให้คุณถูกไล่ออกได้ครับ",
    sender: "bot",
  },
];