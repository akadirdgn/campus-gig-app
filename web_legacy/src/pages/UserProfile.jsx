import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { db } from '../firebase';
import { doc, getDoc, collection, query, where, orderBy, onSnapshot } from 'firebase/firestore';

export default function UserProfile() {
  const { userId } = useParams();
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!userId) return;

    // 1. Kullanıcı Bilgilerini Çek
    const fetchUser = async () => {
      try {
        const userDoc = await getDoc(doc(db, 'users', userId));
        if (userDoc.exists()) {
          setUser(userDoc.data());
        }
      } catch (err) {
        console.error(err);
      }
    };

    // 2. Yorumları Çek (Real-time)
    const q = query(
      collection(db, 'reviews'),
      where('target_id', '==', userId),
      orderBy('created_at', 'desc')
    );

    const unSubReviews = onSnapshot(q, (snapshot) => {
      let list = [];
      snapshot.forEach(doc => list.push({ id: doc.id, ...doc.data() }));
      setReviews(list);
      setLoading(false);
    });

    fetchUser();
    return () => unSubReviews();
  }, [userId]);

  if (loading) return (
    <div className="flex items-center justify-center h-screen bg-[#F8F9FB]">
      <div className="w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
    </div>
  );

  const averageRating = reviews.length > 0 
    ? (reviews.reduce((acc, curr) => acc + curr.rating, 0) / reviews.length).toFixed(1)
    : 0;

  return (
    <div className="min-h-screen bg-[#F8F9FB] flex flex-col">
      {/* Header */}
      <div className="bg-white px-6 py-8 flex flex-col items-center relative shadow-sm rounded-b-[40px] z-10">
        <button 
          onClick={() => navigate(-1)}
          className="absolute left-6 top-8 p-3 bg-gray-50 rounded-2xl active:scale-90 transition-all">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 19l-7-7 7-7" /></svg>
        </button>

        <div className="w-24 h-24 rounded-[32px] bg-gradient-to-br from-indigo-500 to-purple-600 p-1 shadow-2xl shadow-indigo-200 mb-4 animate-pop-in">
           <div className="w-full h-full bg-white rounded-[30px] overflow-hidden">
              <img src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${userId}`} alt="avatar" />
           </div>
        </div>

        <h1 className="text-[20px] font-black text-[#111827] mb-2">{user?.firstName} {user?.lastName}</h1>
        
        <div className="flex flex-wrap justify-center gap-2 mb-8 px-4">
           <span className="px-3 py-1.5 bg-indigo-50 text-indigo-500 text-[9px] font-black uppercase tracking-widest rounded-xl border border-indigo-100">
              🏫 {user?.university || 'Üniversite Belirtilmedi'}
           </span>
           <span className="px-3 py-1.5 bg-emerald-50 text-emerald-600 text-[9px] font-black uppercase tracking-widest rounded-xl border border-emerald-100">
              📚 {user?.department || 'Bölüm Belirtilmedi'}
           </span>
           <span className="px-3 py-1.5 bg-purple-50 text-purple-600 text-[9px] font-black uppercase tracking-widest rounded-xl border border-purple-100">
              🎓 {user?.grade || 'Hazırlık/1'}. Sınıf
           </span>
           {user?.isPremium && (
             <span className="px-3 py-1.5 bg-amber-50 text-amber-500 text-[9px] font-black uppercase tracking-widest rounded-xl border border-amber-100 animate-pulse">
               👑 PREMIUM
             </span>
           )}
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-12 w-full max-w-[280px] px-4">
           <div className="flex flex-col items-center">
              <span className="text-[22px] font-black text-[#111827]">{reviews.length}</span>
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-[0.2em]">Yorum</span>
           </div>
           <div className="flex flex-col items-center relative">
              <div className="absolute -top-1 -right-4 flex items-center justify-center">
                 <span className="text-yellow-400 text-sm drop-shadow-sm animate-bounce">⭐</span>
              </div>
              <span className="text-[22px] font-black text-[#111827]">{averageRating}</span>
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-[0.2em]">Puan</span>
           </div>
        </div>
      </div>

      {/* Reviews Content */}
      <div className="flex-1 px-6 pt-10 pb-20">
        <h3 className="text-[14px] font-black text-[#111827] uppercase tracking-widest mb-6 flex items-center gap-2">
           <span className="w-2 h-2 rounded-full bg-indigo-500"></span>
           Kullanıcı Yorumları
        </h3>

        {reviews.length === 0 ? (
          <div className="bg-white rounded-[32px] p-10 flex flex-col items-center text-center border border-dashed border-gray-200">
             <div className="text-3xl mb-4 grayscale opacity-50">✨</div>
             <p className="text-[12px] font-bold text-gray-400 italic">Henüz bir değerlendirme yapılmamış.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {reviews.map((rev) => (
              <div key={rev.id} className="bg-white p-5 rounded-[32px] shadow-sm border border-gray-100 animate-fade-in group hover:shadow-md transition-all">
                <div className="flex justify-between items-start mb-3">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-2xl bg-gray-50 overflow-hidden">
                       <img src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${rev.writer_id}`} alt="avatar" />
                    </div>
                    <div className="flex flex-col">
                      <span className="text-[13px] font-black text-[#111827]">{rev.writer_name}</span>
                      <span className="text-[9px] font-bold text-indigo-400 uppercase truncate max-w-[150px]">{rev.gig_title}</span>
                    </div>
                  </div>
                  <div className="flex gap-0.5">
                    {[...Array(5)].map((_, i) => (
                      <span key={i} className={`text-[10px] ${i < rev.rating ? 'grayscale-0' : 'grayscale opacity-20'}`}>⭐</span>
                    ))}
                  </div>
                </div>
                <p className="text-[12px] font-medium text-gray-500 leading-relaxed italic pl-1">
                  "{rev.comment || 'Puan verildi.'}"
                </p>
                <div className="flex justify-end mt-2">
                  <span className="text-[8px] font-bold text-gray-300 uppercase underline decoration-indigo-200 underline-offset-4">
                    {rev.created_at?.toDate().toLocaleDateString('tr-TR')}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Floating Action Hint */}
      <div className="fixed bottom-6 left-6 right-6 pointer-events-none">
         <div className="bg-gradient-to-r from-gray-900 to-indigo-950 text-white rounded-2xl p-4 flex items-center justify-between shadow-2xl animate-fade-in border border-white/5">
            <div className="flex items-center gap-3">
               <div className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-xs">💬</div>
               <span className="text-[10px] font-black text-white/80 uppercase tracking-widest">Güvenli Topluluk</span>
            </div>
            <span className="text-[9px] font-bold text-white/40 italic">Gerçek kullanıcı yorumları</span>
         </div>
      </div>
    </div>
  );
}
