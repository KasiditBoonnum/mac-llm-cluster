import { useState, useRef, useEffect } from "react";
import UploadMenu from "../popup/UploadMenu";
import ModelSelector from "../popup/ModelSelector";

export default function ChatInput() {

  const [showUpload, setShowUpload] = useState(false);
  const [showModel, setShowModel] = useState(false);

  const [selectedModel, setSelectedModel] =
    useState("qwen2.5");

  const textareaRef =
    useRef<HTMLTextAreaElement>(null);

  // wrapper ของ popup ทั้งหมด
  const popupRef = useRef<HTMLDivElement>(null);

  // =========================
  // ปิด modal เมื่อคลิกข้างนอก
  // =========================
  useEffect(() => {

    const handleClickOutside = (
      event: MouseEvent
    ) => {

      if (
        popupRef.current &&
        !popupRef.current.contains(
          event.target as Node
        )
      ) {
        setShowUpload(false);
        setShowModel(false);
      }
    };

    document.addEventListener(
      "mousedown",
      handleClickOutside
    );

    return () => {
      document.removeEventListener(
        "mousedown",
        handleClickOutside
      );
    };

  }, []);

  // =========================
  // textarea auto resize
  // =========================
  const handleInput = () => {

    const textarea = textareaRef.current;

    if (!textarea) return;

    textarea.style.height = "auto";

    const maxHeight = 80;

    textarea.style.height =
      Math.min(
        textarea.scrollHeight,
        maxHeight
      ) + "px";
  };

  return (
    <div className="p-4 bg-white border-t">

      <div
        ref={popupRef}
        className="
          relative
          border-2
          rounded-[40px]
          px-8
          py-0
          bg-[#fafafa]
        "
      >

        {/* Upload popup */}
        {showUpload && (
          <UploadMenu />
        )}

        {/* Model popup */}
        {showModel && (
          <ModelSelector
            onSelect={(model) => {
              setSelectedModel(model);
              setShowModel(false);
            }}
          />
        )}

        {/* Input */}
        <textarea
          ref={textareaRef}
          rows={1}
          onInput={handleInput}
          placeholder="พิมพ์ข้อความ...."
          className="
            w-full
            outline-none
            resize-none
            text-lg
            bg-transparent
            py-3
            overflow-y-auto
            min-h-[48px]
            max-h-[80px]
          "
        />

        <div className="
          flex
          justify-between
          items-center
        ">

          <div className="flex items-center gap-8">

            {/* Upload button */}
            <button
              onClick={() => {

                // ปิด model modal ก่อน
                setShowModel(false);

                // toggle upload
                setShowUpload(!showUpload);

              }}
              className="text-xl cursor-pointer"
            >
              +
            </button>

            {/* Model selector */}
            <button
              onClick={() => {

                // ปิด upload modal ก่อน
                setShowUpload(false);

                // toggle model
                setShowModel(!showModel);

              }}
              className="
                underline
                text-xl
                cursor-pointer
              "
            >
              {"< " + selectedModel + " >"}
            </button>

          </div>

          {/* Send */}
          <button
            className="
              bg-[#006C68]
              px-6
              py-2
              mb-1
              rounded-3xl
              text-xl
              font-bold
              text-white
              cursor-pointer
            "
          >
            ส่ง
          </button>
        </div>

      </div>

      <p className="
        text-sm
        text-gray-500
        mt-2
        px-2
      ">
        KU_CHAT นี้ยังเป็นระบบทดลอง คำตอบอาจมีความผิดพลาดได้
      </p>

    </div>
  );
}