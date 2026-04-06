import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { db } from '../firebase';
import { collection, query, where, getDocs, deleteDoc, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { useNavigate } from 'react-router-dom';

export default function MyGigs() {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const [gigs, setGigs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingGig, setEditingGig] = useState(null);
  const [editData, setEditData] = useState({ title: '', description: '', price: 0 });

  useEffect(() => {
    if (!currentUser) return;
    fetchGigs();
  }, [currentUser]);

  const fetchGigs = async () => {
    setLoading(true);
    try {
      const servicesQ = query(collection(db, 'services'), where('creator_id', '==', currentUser.uid));
      const bountiesQ = query(collection(db, 'bounties'), where('creator_id', '==', currentUser.uid));
      
      const [servicesSnap, bountiesSnap] = await Promise.all([getDocs(servicesQ), getDocs(bountiesQ)]);
      
      const allGigs = [
        ...servicesSnap.docs.map(doc => ({ id: doc.id, collection: 'services', ...doc.data() })),
        ...bountiesSnap.docs.map(doc => ({ id: doc.id, collection: 'bounties', ...doc.data() }))
      ];
      
      setGigs(allGigs.sort((a,b) => b.created_at?.toMillis() - a.created_at?.toMillis()));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (gig) => {
    if (!window.confirm("Bu ilanı silmek istediğinize emin misiniz?")) return;
    try {
      await deleteDoc(doc(db, gig.collection, gig.id));
      setGigs(gigs.filter(g => g.id !== gig.id));
    } catch (err) {
      alert("Silme hatası: " + err.message);
    }
  };

  const startEdit = (gig) => {
    setEditingGig(gig);
    setEditData({ title: gig.title, description: gig.description, price: gig.price });
  };

  const handleUpdate = async () => {
    try {
      await updateDoc(doc(db, editingGig.collection, editingGig.id), {
        ...editData,
        updated_at: serverTimestamp()
      });
      setEditingGig(null);
      fetchGigs();
      alert("İlan başarıyla güncellendi.");
    } catch (err) {
      alert("Güncelleme hatası: " + err.message);
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#FAFAFC] relative">
      <div className="p-6">
        <div className="flex items-center gap-4 mb-8">
           <button onClick={() => navigate(-1)} className="p-2 bg-white rounded-xl shadow-sm border border-gray-100 active:scale-95 transition-all">
             <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 19l-7-7 7-7" /></svg>
           </button>
           <h1 className="text-2xl font-black text-[#111827] tracking-tight">İlanlarım</h1>
        </div>

        {loading ? (
          <div className="flex justify-center p-20">
            <div className="w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
          </div>
        ) : gigs.length === 0 ? (
          <div className="text-center p-10 bg-white rounded-[32px] border border-dashed border-gray-200">
            <span className="text-4xl block mb-4">📭</span>
            <p className="text-gray-400 font-bold text-[13px]">Henüz bir ilanınız bulunmuyor.</p>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {gigs.map(gig => (
              <div key={gig.id} className="bg-white p-5 rounded-[28px] border border-gray-100 shadow-sm relative overflow-hidden group">
                 <div className={`absolute top-0 right-0 px-4 py-1.5 rounded-bl-2xl text-[9px] font-black uppercase tracking-widest text-white ${gig.collection === 'services' ? 'bg-emerald-500' : 'bg-indigo-500'}`}>
                    {gig.collection === 'services' ? 'Hizmet' : 'Görev'}
                 </div>
                 
                 <h3 className="text-[15px] font-black text-[#111827] mb-1 pr-16">{gig.title}</h3>
                 <p className="text-[12px] text-gray-400 font-medium line-clamp-2 mb-4">{gig.description}</p>
                 
                 <div className="flex items-center justify-between mt-auto">
                    <div className="flex flex-col">
                       <span className="text-[9px] font-black text-gray-300 uppercase tracking-widest mb-1">Fiyat</span>
                       <span className={`text-[14px] font-black ${gig.price_type === 'swap' ? 'text-purple-600' : 'text-emerald-600'}`}>
                          {gig.price_type === 'swap' ? '1 Saat ZK' : `${gig.price} CGT`}
                       </span>
                    </div>
                    <div className="flex gap-2">
                       <button onClick={() => startEdit(gig)} className="bg-gray-50 text-gray-400 p-2.5 rounded-xl border border-gray-100 hover:bg-gray-100 transition-all">
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                       </button>
                       <button onClick={() => handleDelete(gig)} className="bg-red-50 text-red-400 p-2.5 rounded-xl border border-red-100 hover:bg-red-100 transition-all">
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                       </button>
                    </div>
                 </div>
                 
                 <div className="mt-4 pt-4 border-t border-dashed border-gray-100 flex items-center gap-2">
                    <div className="w-1.5 h-1.5 rounded-full bg-amber-400"></div>
                    <span className="text-[9px] font-bold text-gray-400 uppercase tracking-widest">Yayında (15 günden az kaldı)</span>
                 </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Edit Modal */}
      {editingGig && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-black/40 backdrop-blur-sm animate-fade-in">
           <div className="bg-white rounded-[40px] p-8 w-full max-w-[400px] shadow-2xl animate-pop-in">
              <h3 className="text-[20px] font-black text-[#111827] mb-6 tracking-tight">İlanı Düzenle</h3>
              
              <div className="flex flex-col gap-4">
                 <div className="flex flex-col gap-1.5">
                    <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest pl-1">Başlık</label>
                    <input 
                       type="text" 
                       value={editData.title}
                       onChange={(e) => setEditData({...editData, title: e.target.value})}
                       className="w-full bg-gray-50 border border-gray-100 rounded-2xl py-3 px-4 text-[13px] font-bold text-gray-800"
                    />
                 </div>
                 <div className="flex flex-col gap-1.5">
                    <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest pl-1">Açıklama</label>
                    <textarea 
                       value={editData.description}
                       onChange={(e) => setEditData({...editData, description: e.target.value})}
                       className="w-full bg-gray-50 border border-gray-100 rounded-2xl py-3 px-4 text-[13px] font-bold text-gray-800 h-24 resize-none"
                    />
                 </div>
                 {editingGig.price_type === 'token' && (
                    <div className="flex flex-col gap-1.5">
                       <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest pl-1">Fiyat (CGT)</label>
                       <input 
                          type="number" 
                          value={editData.price}
                          onChange={(e) => setEditData({...editData, price: Number(e.target.value)})}
                          className="w-full bg-gray-50 border border-gray-100 rounded-2xl py-3 px-4 text-[13px] font-bold text-gray-800"
                       />
                    </div>
                 )}
              </div>

              <div className="flex gap-3 mt-8">
                 <button onClick={() => setEditingGig(null)} className="flex-1 py-4 bg-gray-50 text-gray-400 font-black text-[11px] uppercase tracking-widest rounded-2xl active:bg-gray-100 transition-all">İptal</button>
                 <button onClick={handleUpdate} className="flex-2 py-4 bg-[#4F46E5] text-white font-black text-[11px] uppercase tracking-widest rounded-2xl shadow-lg shadow-indigo-500/20 active:scale-95 transition-all">Güncelle</button>
              </div>
           </div>
        </div>
      )}
    </div>
  );
}
