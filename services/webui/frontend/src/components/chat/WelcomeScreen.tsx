export default function WelcomeScreen() {
  return (
    <div
      className="
        flex
        flex-col
        items-center
        justify-center
        h-full
        px-6
      "
    >

      {/* กล่อง welcome */}
      <div
        className="
          bg-[#ECECEC]
          rounded-[30px]
          shadow-md
          px-10
          py-14
          text-center
          max-w-[800px]
          w-full
          mb-10
        "
      >
        <h1 className="text-5xl font-bold !text-black">
          สวัสดีครับ วันนี้มีอะไรให้ผมช่วยครับ?
        </h1>
      </div>

      {/* Suggested prompt */}
      <div className="flex items-center gap-4">
        <span className="text-lg font-medium">
          คำถามแนะนำ
        </span>

        <div
          className="
            border-2
            border-[#00B56A]
            rounded-full
            px-6
            py-3
            text-lg
            hover:bg-[#dff7ec]
            transition
          "
        >
          ตอนนี้มหาวิทยาลัยเกษตรศาสตร์มีกี่คณะ
        </div>
      </div>

    </div>
  );
}