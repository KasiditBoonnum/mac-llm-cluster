import DeepSeekIcon from "../../assets/deepseekIcon.png";
import Phi4Icon from "../../assets/phiIcon.png";
import QwenIcon from "../../assets/qwenIcon.png";

const models = [
  {
    name: "qwen2.5",
    desc: "ทำงานได้หลากหลาย",
    img: QwenIcon,
  },
  {
    name: "qwen3.6",
    desc: "ฉลาดมากขึ้น",
    img: QwenIcon,
  },
  {
    name: "phi4",
    desc: "ตอบเร็ว",
    img: Phi4Icon,
  },
  {
    name: "deepseek",
    desc: "เขียนโค้ดเก่ง",
    img: DeepSeekIcon,
  },
];

type Props = {
  onSelect: (model: string) => void;
};

export default function ModelSelector({
  onSelect,
}: Props) {
  return (
    <div className="
      absolute
      bottom-14
      left-15
      bg-white
      rounded-3xl
      shadow-xl
      p-2
      w-[300px]
      z-50
      border border-gray-200
    ">

      <h2 className="
        text-3xl
        font-bold
        mb-6
        py-4
        !text-black
      ">
        {">>> เลือกโมเดล <<<"}
      </h2>

      <div className="space-y-3">

        {models.map((model) => (
          <button
            key={model.name}
            onClick={() =>
              onSelect(model.name)
            }
            className="
              flex
              items-center
              gap-4
              hover:bg-gray-100
              p-3
              rounded-2xl
              w-full
              transition
            "
          >

            {/* icon */}
            <img
              src={model.img}
              alt={model.name}
              className="
                w-12
                h-12
                object-contain
                shrink-0
              "
            />

            {/* text */}
            <div className="
              flex
              flex-col
              items-start
            ">

              <span className="
                text-2xl
                font-bold
                text-black
                leading-none
              ">
                {model.name}
              </span>

              <span className="
                text-gray-500
                text-sm
                mt-1
              ">
                {model.desc}
              </span>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}