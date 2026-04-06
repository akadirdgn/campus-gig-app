import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { db } from '../firebase';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';

export default function BottomNavigation() {
  const location = useLocation();
  const { currentUser } = useAuth();
  const [hasUnread, setHasUnread] = useState(false);

  useEffect(() => {
    if (!currentUser) return;

    // Kullanıcının okunmamış mesajı olan odaları dinle
    const q = query(
      collection(db, 'chat_rooms'),
      where('unread_by', 'array-contains', currentUser.uid)
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      setHasUnread(!snapshot.empty);
    }, (error) => {
      console.error("Unread messages listener error:", error);
    });

    return () => unsubscribe();
  }, [currentUser]);

  const navItems = [
    { name: 'Ana Sayfa', path: '/', icon: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6' },
    { name: 'İlan Ver', path: '/create-gig', icon: 'M12 4v16m8-8H4', center: true },
    { name: 'Mesajlar', path: '/messages', icon: 'M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z' },
    { name: 'Hesabım', path: '/profile', icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z' },
  ];

  return (
    <div className="absolute bottom-6 left-6 right-6 h-[72px] bg-white/95 backdrop-blur-xl border border-emerald-50 z-50 rounded-[28px] px-3 flex justify-around items-center shadow-[0_10px_40px_rgba(16,185,129,0.12)]">
      {navItems.map((item) => {
        const isActive = location.pathname === item.path;

        return (
          <Link
            key={item.name}
            to={item.path}
            className={`relative flex flex-col items-center justify-center transition-all duration-300 w-16 h-full active:scale-95`}
          >
            {/* Arkaplan Glow (Sadece Aktifken) */}
            {isActive && !item.center && (
              <div className="absolute inset-0 bg-emerald-50 rounded-2xl transform scale-75 blur-md opacity-60"></div>
            )}

            <div className={`relative z-10 flex flex-col items-center justify-center gap-1`}>
              {item.center ? (
                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center transition-all duration-500 shadow-xl ${isActive ? 'bg-gradient-to-tr from-[#059669] to-[#10B981] shadow-emerald-200 rotate-45 scale-110' : 'bg-gradient-to-tr from-[#10B981] to-[#3B82F6] shadow-blue-100'}`}>
                  <svg xmlns="http://www.w3.org/2000/svg" className={`h-7 w-7 text-white transition-all duration-500 ${isActive ? '-rotate-45' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                    <path strokeLinecap="round" strokeLinejoin="round" d={item.icon} />
                  </svg>
                </div>
              ) : (
                <div className="relative">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    className={`h-6 w-6 transition-all duration-300 ${isActive ? 'text-[#10B981] scale-110' : 'text-gray-400 opacity-70'}`}
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={isActive ? 2.5 : 2}
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" d={item.icon} />
                  </svg>
                  {/* Okunmamış Mesaj İşareti */}
                  {item.path === '/messages' && hasUnread && (
                    <span className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 border-2 border-white rounded-full shadow-[0_0_8px_rgba(239,68,68,0.5)] animate-pulse"></span>
                  )}
                </div>
              )}
              <span className={`text-[9px] font-black uppercase tracking-widest text-center transition-all duration-300 ${isActive ? 'text-[#059669]' : 'text-gray-400 opacity-60'}`}>
                {item.name}
              </span>
            </div>

            {/* Aktif İndikatörü */}
            {isActive && !item.center && (
              <div className="absolute -bottom-1 w-1.5 h-1.5 rounded-full bg-[#10B981] shadow-[0_0_8px_rgba(16,185,129,0.6)]"></div>
            )}
          </Link>
        )
      })}
    </div>
  );
}
