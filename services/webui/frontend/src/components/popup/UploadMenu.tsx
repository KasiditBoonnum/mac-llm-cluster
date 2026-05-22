import { useRef } from "react";
import UploadIcon from "../../assets/UploadIcon.png";

export default function UploadMenu() {

  // reference ไปยัง input file
  const fileInputRef =
    useRef<HTMLInputElement>(null);

  // เปิด file picker
  const handleOpenFilePicker = () => {
    fileInputRef.current?.click();
  };

  // เมื่อเลือกไฟล์
  const handleFileChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {

    const files = event.target.files;

    if (!files || files.length === 0)
      return;

    const file = files[0];

    console.log("ชื่อไฟล์:", file.name);
    console.log("ชนิดไฟล์:", file.type);
    console.log("ขนาด:", file.size);

    // TODO:
    // ส่ง file ไป backend
  };

  return (
    <div className="
      absolute
      bottom-14
      left-5
      bg-white
      shadow-xl
      rounded-3xl
      p-2
      w-[250px]
      z-50
      border border-gray-200
    ">

      {/* hidden input */}
      <input
        type="file"
        ref={fileInputRef}
        onChange={handleFileChange}
        className="hidden"
      />

      {/* upload button */}
      <button
        onClick={handleOpenFilePicker}
        className="
          flex
          gap-4
          w-full
          p-4
          hover:bg-gray-100
          rounded-xl
          items-center
        "
      >

        <img
          src={UploadIcon}
          alt="Upload Icon"
          className="w-6 h-6"
        />

        อัปโหลดไฟล์

      </button>

    </div>
  );
}

// ตัวอย่างการส่งไฟล์ไป backend ด้วย fetch
// const formData = new FormData();

// formData.append("file", file);

// fetch("http://localhost:3000/upload", {
//   method: "POST",
//   body: formData,
// });