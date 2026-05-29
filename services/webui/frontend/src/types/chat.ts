export type Message = {
  id: number | string;
  text: string;
  sender: "user" | "bot";
  animate?: boolean;
};