import React from 'react';
import { useAuth } from '../context/AuthContext';
import { useModal } from '../context/ModalContext';
import { useNavigate } from 'react-router-dom';

export default function Profile() {
  const { userData, logout } = useAuth();
  const { showModal } = useModal();
  const navigate = useNavigate();

  const handleLogout = () => {
    showModal({
      title: 'Oturumu Kapat',
      message: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz? Devam etmek için onaylayın.',
      type: 'warning',
      confirmText: 'Çıkış Yap',
      cancelText: 'Vazgeç',
      onConfirm: async () => {
        try {
          await logout();
          navigate('/login');
        } catch (error) {
          console.error("Çıkış hatası:", error);
        }
      }
    });
  };

  if (!userData) return null;

  return (
    <div className="flex flex-col h-full bg-white relative overflow-hidden">
      {/* Üst Renkli Alan */}
      <div className="h-56 bg-gradient-to-br from-blue-600 via-purple-600 to-indigo-700 relative">
        <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] opacity-10"></div>
        <div className="absolute -bottom-16 left-0 right-0 flex justify-center">
          <div className="relative">
            <img
              src={userData.avatar_url || `https://api.dicebear.com/7.x/notionists/svg?seed=${userData.id}&backgroundColor=EADDFF`}
              alt="Avatar"
              className="w-32 h-32 rounded-[40px] border-8 border-white shadow-2xl bg-white"
            />
            {userData.isPremium && (
              <div className="absolute -top-4 -right-4 bg-gradient-to-tr from-yellow-400 to-orange-500 rounded-2xl p-2 shadow-xl border-4 border-white rotate-12">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-white" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.286 3.97a1 1 0 00.95.69h4.18c.969 0 1.371 1.24.588 1.81l-3.388 2.46a1 1 0 00-.364 1.118l1.286 3.97c.3.921-.755 1.688-1.54 1.118l-3.388-2.46a1 1 0 00-1.175 0l-3.388 2.46c-.784.57-1.838-.197-1.539-1.118l1.286-3.97a1 1 0 00-.364-1.118L2.05 9.397c-.783-.57-.38-1.81.588-1.81h4.18a1 1 0 00.95-.69l1.286-3.97z" />
                </svg>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="mt-20 px-8 flex flex-col items-center flex-1">
        <h2 className="text-[24px] font-black text-[#111827] tracking-tight">{userData.firstName} {userData.lastName}</h2>
        <p className="text-gray-400 font-bold text-[11px] uppercase tracking-widest mt-1">{userData.department} • {userData.university.toUpperCase()}</p>

        {/* Cüzdan Kartları */}
        <div className="grid grid-cols-2 gap-4 w-full mt-10">
          <div className="bg-[#F4F0FF] p-5 rounded-[32px] border border-purple-100 flex flex-col gap-1 items-center justify-center">
            <span className="text-[10px] font-bold text-purple-400 uppercase tracking-widest">CG Token</span>
            <span className="text-[20px] font-black text-purple-700">{userData.wallet_cgt || 0}</span>
          </div>
          <div className="bg-[#EFF6FF] p-5 rounded-[32px] border border-blue-100 flex flex-col gap-1 items-center justify-center">
            <span className="text-[10px] font-bold text-blue-400 uppercase tracking-widest">Zaman Puanı</span>
            <span className="text-[20px] font-black text-blue-700">{userData.wallet_time_credit || 0}</span>
          </div>
        </div>

        {/* Menü Seçenekleri */}
        <div className="w-full mt-8 flex flex-col gap-3">
          <div className="p-5 bg-gray-50 rounded-[24px] border border-gray-100 flex items-center justify-between group active:scale-[0.98] transition-all cursor-pointer">
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center text-lg shadow-sm border border-gray-100">🎓</div>
              <div className="flex flex-col">
                <span className="text-[13px] font-black text-[#111827]">Eğitim Bilgilerim</span>
                <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{userData.grade} / {userData.department}</span>
              </div>
            </div>
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-gray-300" viewBox="0 0 20 20" fill="currentColor"><path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" /></svg>
          </div>

          <div 
            onClick={() => navigate('/my-gigs')}
            className="p-5 bg-gray-50 rounded-[24px] border border-gray-100 flex items-center justify-between group active:scale-[0.98] transition-all cursor-pointer">
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center text-lg shadow-sm border border-gray-100">🚀</div>
              <div className="flex flex-col">
                <span className="text-[13px] font-black text-[#111827]">İlanlarım</span>
                <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">İlanlarını düzenle veya sil</span>
              </div>
            </div>
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-gray-300" viewBox="0 0 20 20" fill="currentColor"><path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" /></svg>
          </div>

          <button
            onClick={handleLogout}
            className="p-5 bg-red-50 rounded-[24px] border border-red-100 flex items-center justify-between group active:scale-[0.98] transition-all cursor-pointer mt-4"
          >
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center text-lg shadow-sm border border-red-100">🚪</div>
              <span className="text-[13px] font-black text-red-600 uppercase tracking-widest">Oturumu Kapat</span>
            </div>
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-red-300" viewBox="0 0 20 20" fill="currentColor"><path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" /></svg>
          </button>
        </div>

        <p className="text-[9px] font-bold text-gray-300 uppercase tracking-[0.3em] mt-10 mb-20">CampusGig Beta • v1.0.4</p>
      </div>
    </div>
  );
}
