import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, where, onSnapshot, orderBy } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Messages() {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!currentUser) return;

    // Katılımcılar dizisinde kullanıcının UID'si olan odaları getir
    const q = query(
      collection(db, 'chat_rooms'),
      where('participants', 'array-contains', currentUser.uid)
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const list = [];
      snapshot.forEach(doc => {
        list.push({ id: doc.id, ...doc.data() });
      });

      // Sıralamayı frontend tarafında yapıyoruz (Index hatasını önlemek için)
      const sortedList = list.sort((a, b) => {
        const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
        const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
        return dateB - dateA;
      });

      setRooms(sortedList);
      setLoading(false);
    }, (error) => {
      console.error("Mesajlar yüklenirken hata:", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [currentUser]);

  return (
    <div className="flex flex-col h-full bg-[#FAFAFC] relative overflow-hidden">

      {/* Dynamic Background Blobs - Ocean & Crimson Palette */}
      <div className="absolute top-[-5%] left-[-15%] w-[80%] h-[25%] bg-[#0EA5E9]/10 rounded-full mix-blend-multiply blur-[90px] animate-blob z-0 pointer-events-none"></div>
      <div className="absolute bottom-[15%] right-[-15%] w-[70%] h-[35%] bg-[#F43F5E]/10 rounded-full mix-blend-multiply blur-[100px] animate-blob z-0 pointer-events-none" style={{ animationDelay: '2.5s' }}></div>

      <div className="flex-1 overflow-y-auto no-scrollbar px-6 pt-12 pb-32 z-10 relative">
        <header className="mb-10">
          <div className="flex justify-between items-center mb-2">
            <h1 className="text-[32px] font-black tracking-tighter text-transparent bg-clip-text bg-gradient-to-br from-gray-900 via-gray-700 to-gray-500">
              Mesaj Kutusu
            </h1>
            <div className="w-12 h-12 bg-white rounded-2xl shadow-sm border border-gray-100 flex items-center justify-center relative active:scale-95 transition-all">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              <div className="absolute top-3 right-3 w-3 h-3 bg-[#F43F5E] rounded-full border-2 border-white shadow-sm"></div>
            </div>
          </div>
          <p className="text-gray-400 font-bold text-[10px] uppercase tracking-[0.3em] pl-1"> Görüşmelerim</p>

          {/* New Vibrant Search Bar */}
          <div className="mt-8 flex items-center bg-white rounded-[24px] px-6 py-4 border border-gray-50 shadow-[0_4px_20px_rgba(0,0,0,0.02)] group focus-within:shadow-lg transition-all border-l-4 border-l-[#0EA5E9]">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-gray-400 group-focus-within:text-[#0EA5E9] transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            <input type="text" placeholder="Görüşmelerde ara..." className="ml-3 bg-transparent text-[13px] font-bold text-gray-600 focus:outline-none w-full placeholder:text-gray-300" />
          </div>
        </header>

        {loading ? (
          <div className="flex justify-center items-center py-24">
            <div className="relative w-14 h-14">
              <div className="absolute inset-0 border-4 border-[#0EA5E9]/10 rounded-full"></div>
              <div className="absolute inset-0 border-4 border-[#0EA5E9] border-t-transparent rounded-full animate-spin"></div>
            </div>
          </div>
        ) : rooms.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 px-10 text-center bg-white/60 backdrop-blur-md rounded-[48px] border border-white animate-fade-in shadow-xl mt-6 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-orange-400/10 to-pink-500/10 rounded-full blur-3xl"></div>
            <div className="w-24 h-24 bg-gradient-to-br from-[#FB923C] to-[#DB2777] rounded-[38px] flex items-center justify-center text-4xl mb-8 shadow-2xl shadow-pink-500/20 rotate-6 transform hover:rotate-0 transition-transform duration-500">🌅</div>
            <h3 className="text-[20px] font-black text-[#111827] mb-3 tracking-tight">Kutun Henüz Boş</h3>
            <p className="text-[12px] text-gray-500 font-semibold leading-relaxed max-w-[220px] mx-auto uppercase tracking-widest mb-10 italic">
              İlk adımını at, kampüsünde fark yarat.
            </p>
            <button
              onClick={() => navigate('/')}
              className="px-12 py-4 bg-gradient-to-r from-[#0EA5E9] to-[#6366F1] text-white text-[12px] font-black uppercase tracking-[0.25em] rounded-2xl shadow-xl shadow-blue-500/30 active:scale-95 transition-all hover:opacity-90"
            >
              KEŞFET
            </button>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {rooms.map((room) => {
              const otherParticipantId = room.participants.find(id => id !== currentUser.uid);
              const otherParticipantName = currentUser.uid === room.buyer_id ? room.seller_name : room.buyer_name;
              const isUnread = room.unread_by?.includes(currentUser.uid);

              return (
                <div
                  key={room.id}
                  onClick={() => navigate(`/chat/${room.id}`)}
                  className={`group p-4 rounded-[24px] border transition-all duration-300 cursor-pointer relative overflow-hidden bg-white
                    ${isUnread ? 'border-emerald-100 shadow-[0_8px_30px_rgb(16,185,129,0.06)] ring-1 ring-emerald-50' : 'border-gray-50 hover:border-gray-100 hover:shadow-sm'}`}
                >
                  {/* Unread Indicator Dot */}
                  {isUnread && (
                    <div className="absolute top-4 right-4 flex items-center gap-1.5">
                       <span className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(16,185,129,0.4)]"></span>
                       <span className="text-[10px] font-black text-emerald-600 uppercase tracking-tighter">YENİ</span>
                    </div>
                  )}

                  <div className="flex items-center gap-4">
                    {/* Avatar with Status */}
                    <div className="relative flex-shrink-0">
                      <div className={`p-1 rounded-2xl ${isUnread ? 'bg-emerald-50' : 'bg-gray-50'}`}>
                        <img
                          src={`https://api.dicebear.com/7.x/notionists/svg?seed=${otherParticipantId}&backgroundColor=F8FAFC`}
                          alt="User"
                          className="w-14 h-14 rounded-[14px] object-cover bg-white"
                        />
                      </div>
                      {room.status === 'completed' && (
                        <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-emerald-500 border-2 border-white rounded-full flex items-center justify-center shadow-sm">
                          <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" /></svg>
                        </div>
                      )}
                    </div>

                    {/* Content */}
                    <div className="flex flex-col flex-1 min-w-0">
                      <div className="flex justify-between items-center mb-0.5">
                        <h4 className="text-[15px] font-bold text-gray-900 tracking-tight truncate">
                          {otherParticipantName}
                        </h4>
                        <span className="text-[10px] font-semibold text-gray-400 tabular-nums">
                          {room.last_message_at?.toDate ? new Date(room.last_message_at.toDate()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                        </span>
                      </div>

                      <p className={`text-[12px] truncate leading-relaxed ${isUnread ? 'text-gray-900 font-bold' : 'text-gray-500 font-medium'}`}>
                        {room.last_sender_id === currentUser.uid ? (
                          <span className="text-gray-400 font-black text-[10px] uppercase mr-1">Siz:</span>
                        ) : null}
                        {room.last_message || 'Yeni görüşme başlatıldı'}
                      </p>

                      <div className="flex items-center gap-2 mt-2.5">
                        <div className="px-2.5 py-1 bg-gray-50 rounded-lg flex items-center gap-1.5 border border-gray-100/50">
                          <div className="w-1 h-1 rounded-full bg-gray-300"></div>
                          <span className="text-[9px] font-black text-gray-400 uppercase tracking-wider">
                            {room.gig_title}
                          </span>
                        </div>
                        {room.status === 'escrow_locked' && (
                          <div className="px-2.5 py-1 bg-blue-50/50 rounded-lg flex items-center gap-1 border border-blue-100/50">
                            <span className="text-[9px] font-black text-blue-500 uppercase tracking-wider">GÜVENLİ ÖDEME 🔒</span>
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="text-gray-300 group-hover:text-gray-400 transition-colors pl-2">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                      </svg>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );

}
