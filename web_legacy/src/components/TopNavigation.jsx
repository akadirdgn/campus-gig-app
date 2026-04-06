import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useModal } from '../context/ModalContext';
import { useNavigate } from 'react-router-dom';

export default function TopNavigation() {
  const { userData, logout } = useAuth();
  const { showModal } = useModal();
  const navigate = useNavigate();
  const [showMenu, setShowMenu] = useState(false);

  const handleLogout = () => {
    setShowMenu(false);
    showModal({
      title: 'Çıkış Yap',
      message: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
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

  return (
    <div className="sticky top-0 left-0 right-0 h-20 bg-white/70 backdrop-blur-md border-b border-gray-100 z-50 flex justify-between items-center px-6 pt-safe shadow-[0_8px_30px_rgb(0,0,0,0.02)] transition-all">
      {/* Sol: Premium Logo Section */}
      <div className="flex flex-col justify-center gap-0.5 group cursor-pointer" onClick={() => navigate('/')}>
        <div className="flex items-center gap-1.5">
          <div className="w-2.5 h-6 bg-gradient-to-b from-[#10B981] to-[#6366F1] rounded-full shadow-lg shadow-emerald-500/20 group-hover:scale-y-110 transition-transform duration-300"></div>
          <span className="text-[22px] font-black tracking-tighter text-gray-900 drop-shadow-sm">
            Campus<span className="text-gray-500 group-hover:text-[#6366F1] transition-colors">Gig</span>
          </span>
        </div>
        <div className="flex items-center gap-1.5 opacity-40">
          <span className="text-[8px] uppercase tracking-[0.4em] font-black text-gray-400 pl-4">Üniversite Ağı</span>
        </div>
      </div>

      {/* Sağ: Bakiye Dashboard ve Profil */}
      <div className="flex items-center gap-4">
        {userData ? (
          <>
            {/* Unified Balance Dashboard */}
            <div className="bg-gray-50/50 border border-gray-100 p-1 rounded-2xl flex items-center gap-1 shadow-inner">
              {/* Token Display */}
              <div className="bg-white px-3 py-1.5 rounded-xl flex items-center gap-2 border border-gray-50 shadow-sm min-w-[70px] justify-between group active:scale-95 transition-all">
                 <div className="flex flex-col">
                   <span className="text-[8px] font-black text-gray-300 uppercase -mb-1 tracking-tighter">Token</span>
                   <span className="text-[13px] font-black text-gray-800 tabular-nums leading-none">{userData.wallet_cgt || 0}</span>
                 </div>
                 <div className="w-5 h-5 bg-gradient-to-tr from-[#059669] to-[#10B981] rounded-lg flex items-center justify-center text-[10px] text-white font-black shadow-lg shadow-emerald-500/20 group-hover:rotate-12 transition-transform">
                   T
                 </div>
              </div>

              {/* Zaman Kredisi Display */}
              <div className="bg-white px-3 py-1.5 rounded-xl flex items-center gap-2 border border-gray-50 shadow-sm min-w-[70px] justify-between group active:scale-95 transition-all">
                 <div className="flex flex-col">
                   <span className="text-[8px] font-black text-gray-300 uppercase -mb-1 tracking-tighter">Süre</span>
                   <span className="text-[13px] font-black text-gray-800 tabular-nums leading-none">{userData.wallet_time_credit || 0}</span>
                 </div>
                 <div className="w-5 h-5 bg-gradient-to-tr from-[#4F46E5] to-[#6366F1] rounded-lg flex items-center justify-center text-[10px] text-white font-black shadow-lg shadow-indigo-500/20 group-hover:-rotate-12 transition-transform">
                   Z
                 </div>
              </div>
            </div>

            {/* Avatar / Menü Tetikleyici */}
            <div className="relative">
              <button 
                onClick={() => setShowMenu(!showMenu)}
                className="w-11 h-11 rounded-full border-2 border-white shadow-xl overflow-hidden relative active:scale-95 transition-all outline-none"
              >
                <img src={userData.avatar_url || `https://api.dicebear.com/7.x/notionists/svg?seed=${userData.id}&backgroundColor=EADDFF`} alt="Profile" className="w-full h-full object-cover" />
              </button>
              {/* Statü Dot */}
              <div className="absolute top-0 right-0 w-3 h-3 bg-emerald-500 border-2 border-white rounded-full shadow-sm"></div>
            </div>

            {/* Dropdown Menü (Aynı tasarımın daha profesyonel hali) */}
            {showMenu && (
              <>
                <div className="fixed inset-0 z-40 bg-black/5 backdrop-blur-[1px]" onClick={() => setShowMenu(false)}></div>
                <div className="absolute top-16 right-0 w-60 bg-white/95 backdrop-blur-xl rounded-[32px] shadow-2xl border border-gray-100 p-3 z-50 animate-fade-in origin-top-right">
                  <div className="px-5 py-4 bg-gray-50/50 rounded-[24px] border border-gray-100 mb-2">
                    <p className="text-[14px] font-black text-gray-900 truncate leading-tight">{userData.firstName} {userData.lastName}</p>
                    <p className="text-[10px] text-gray-400 font-bold truncate uppercase tracking-widest opacity-60 mt-0.5">{userData.email}</p>
                  </div>
                  
                  <div className="flex flex-col gap-1">
                    <button onClick={() => { setShowMenu(false); navigate('/profile'); }} className="w-full text-left px-5 py-3.5 text-[13px] font-black text-gray-600 hover:bg-emerald-50 hover:text-emerald-600 rounded-2xl transition-all flex items-center gap-3">
                      <div className="w-9 h-9 bg-white shadow-sm rounded-xl flex items-center justify-center text-lg">👤</div>
                      Profilim
                    </button>
                    
                    <button onClick={handleLogout} className="w-full text-left px-5 py-3.5 text-[13px] font-black text-red-500 hover:bg-red-50 rounded-2xl transition-all flex items-center gap-3">
                      <div className="w-9 h-9 bg-red-50 rounded-xl flex items-center justify-center text-lg">🚪</div>
                      Çıkış Yap
                    </button>
                  </div>
                </div>
              </>
            )}
          </>
        ) : (
          <button 
            onClick={() => navigate('/login')}
            className="px-6 py-2.5 bg-gray-900 text-white rounded-2xl text-[11px] font-black uppercase tracking-widest shadow-xl shadow-gray-900/10 active:scale-95 transition-all"
          >
            GİRİŞ YAP
          </button>
        )}
      </div>
    </div>
  );
}
