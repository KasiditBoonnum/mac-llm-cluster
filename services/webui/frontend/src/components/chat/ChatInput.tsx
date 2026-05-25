import { useState, useRef, useEffect } from "react";
import UploadMenu from "../popup/UploadMenu";
import ModelSelector from "../popup/ModelSelector";

type Props = {
  onSend?: (text: string, files?: File[]) => void;
};

export default function ChatInput({ onSend }: Props) {

  const [showUpload, setShowUpload] = useState(false);
  const [showModel, setShowModel] = useState(false);

  const [selectedModel, setSelectedModel] =
    useState("qwen2.5");

  const textareaRef =
    useRef<HTMLTextAreaElement>(null);

  // ไฟล์ที่เลือก (แสดงเป็นกล่องใน prompt)
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);

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
          <UploadMenu onFileSelect={(file) => {
            setSelectedFiles((prev) => [...prev, file]);
            setShowUpload(false);
            const textarea = textareaRef.current;
            if (textarea) textarea.focus();
          }} />
        )}

        {/* Selected files preview (as boxes) */}
        {selectedFiles.length > 0 && (
          <div className="flex gap-2 mb-2 px-2">
            {selectedFiles.map((f, idx) => (
              <div key={idx} className="flex items-center gap-2 bg-white border rounded-lg px-3 py-2">
                <div className="w-8 h-8 flex items-center justify-center bg-gray-100 rounded">
                  <span className="text-sm">{(f.name.split('.').pop() || 'file').toUpperCase()}</span>
                </div>
                <div className="flex flex-col">
                  <span className="text-sm font-medium max-w-[200px] truncate">{f.name}</span>
                  <span className="text-xs text-gray-500">{f.type || 'unknown'}</span>
                </div>
                <button
                  onClick={() => setSelectedFiles((prev) => prev.filter((_, i) => i !== idx))}
                  className="ml-2 text-gray-400 hover:text-gray-700"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
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
            onClick={() => {
              const textarea = textareaRef.current;
              if (!textarea) return;
              const text = textarea.value.trim();
              if (!text && selectedFiles.length === 0) return;
              // call parent handler if provided (include files)
              if (onSend) onSend(text, selectedFiles.length ? selectedFiles : undefined);
              // clear
              textarea.value = "";
              textarea.style.height = "auto";
              setSelectedFiles([]);
            }}
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