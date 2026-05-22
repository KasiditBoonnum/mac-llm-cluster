import RecycleBin from '../../assets/recycle-bin.png';

export default function UploadMenu() {
  
  return (
    <div className="
      absolute
      top-14
      right-5
      bg-white
      shadow-xl
      rounded-3xl
      p-2
      w-[200px]
      z-50
      border border-gray-200
    ">

      <button className="flex gap-4 w-full p-2 hover:bg-gray-100 rounded-xl">
        <img src={RecycleBin} alt="Recycle Bin Icon" className="w-5 h-5" />
        <h3 className="text-sm font-medium text-black">ลบการสนทนา</h3>
      </button>
    </div>
  );
}