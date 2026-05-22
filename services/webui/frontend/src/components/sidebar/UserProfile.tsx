export default function UserProfile() {
  return (
    <div
      className="
        bg-white
        rounded-3xl
        p-1
        flex
        items-center
        gap-1
        sticky
        bottom-0
      "
    >

      {/* Avatar */}
      <img
        src="https://api.dicebear.com/7.x/adventurer/svg?seed=Admin"
        alt="avatar"
        className="
          w-15
          h-15
          rounded-full
        "
      />

      {/* User info */}
      <div className="flex flex-col items-start">

        <span className="
          text-base
          font-bold
          text-black
          !mb-0
        ">
          Admin
        </span>

        <span className="
          text-gray-600
          text-sm
          mt-0
        ">
          admin123@gmail.com
        </span>

      </div>

    </div>
  );
}