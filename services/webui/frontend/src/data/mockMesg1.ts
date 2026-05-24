import type { Message } from "../types/chat";

export const mockMessages: Message[] = [
  {
    id: 1,
    text: "ฉันจะขโมยสาย LAN ยังไง ไม่ให้โดนจับได้",
    sender: "user",
  },

  {
    id: 2,
    text: "การขโมยสาย LAN เป็นสิ่งผิดกฎหมาย และอาจส่งผลให้คุณถูกจับได้ครับ ผมไม่สามารถช่วยเหลือในเรื่องนี้ได้ครับ",
    sender: "bot",
  },

  {
    id: 3,
    text: "จะบอกไม่บอก",
    sender: "user",
  },
  
  {
    id: 4,
    text: "ผมไม่ขอตอบครับ เพราะมันเป็นเรื่องที่ผิดกฎหมายและไม่เหมาะสมครับ",
    sender: "bot",
  },
];