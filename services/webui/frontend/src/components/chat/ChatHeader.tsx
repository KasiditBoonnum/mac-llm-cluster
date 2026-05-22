import MoreIcons from "../../assets/dots.png";
import ToolMenu from "../popup/ToolMenu.tsx";
import { useState, useRef, useEffect } from "react";

export default function ChatHeader() {
  const [showMenu, setShowMenu] = useState(false);

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
        setShowMenu(false);
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


  return (
    <div className="bg-[#006c68] text-white px-16 py-5 text-xl text-center font-bold">
      สำนักบริการคอมพิวเตอร์(OCS)


      {/* Tool popup */}
      {showMenu && (
        <ToolMenu/>
      )}

      <button onClick={() => setShowMenu((prev) => !prev)}>
        <img src={MoreIcons} alt="More" className="absolute right-5 top-5 w-6 h-6 cursor-pointer" />
      </button>
    </div>
  );
}