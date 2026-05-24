import RecycleBin from '../../assets/image/recycle-bin.png';

type Props = {
  onDelete?: () => void;
  onClose?: () => void;
};

export default function ToolMenu({ onDelete, onClose }: Props) {

  const handleClick = () => {
    const ok = window.confirm("ยืนยันการลบการสนทนานี้? การกระทำนี้เป็นแบบชั่วคราว (รีเฟรชจะคืนค่า)");
    if (ok) {
      onDelete?.();
    }
    onClose?.();
  };

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

      <button onClick={handleClick} className="flex gap-4 w-full p-2 hover:bg-gray-100 rounded-xl">
        <img src={RecycleBin} alt="Recycle Bin Icon" className="w-5 h-5" />
        <h3 className="text-sm font-medium text-black">ลบการสนทนา</h3>
      </button>
    </div>
  );
}