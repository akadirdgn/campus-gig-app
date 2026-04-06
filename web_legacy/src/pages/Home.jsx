import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';
import { collection, query, orderBy, onSnapshot, doc, setDoc, getDoc, serverTimestamp } from 'firebase/firestore';

export default function Home() {
  const { userData, currentUser } = useAuth();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('marketplace'); // marketplace (Hizmetler), bounties (Talepler)
  const [services, setServices] = useState([]);
  const [bounties, setBounties] = useState([]);
  const [loading, setLoading] = useState(true);

  // Chat Başlatma Fonksiyonu
  const startChat = async (item) => {
    if (!currentUser) return navigate('/login');
    if (item.creator_id === currentUser.uid) {
      alert("Bu sizin kendi ilanınız.");
      return;
    }

    // Oda var mı kontrol et (id: gigId_buyerId)
    // NOT: Görev (Bounty) ise buyer_id ilanı açan kişidir, Marketplace ise buyer_id currentUser'dır. 
    // Ancak daha tutarlı olması için odanın ID'sini gigId_otherUserId şeklinde kurguluyoruz.
    const isBounty = item.type === 'bounties';
    const roomId = `${item.id}_${currentUser.uid}`;
    const roomRef = doc(db, 'chat_rooms', roomId);

    try {
      const roomSnap = await getDoc(roomRef);

      if (!roomSnap.exists()) {
        // Oda yoksa oluştur
        await setDoc(roomRef, {
          gig_id: item.id,
          gig_title: item.title,
          // Eğer BU BİR GÖREVSE (Bounty): İlanı açan ALICI'dır (Buyer), giden kişi SATICI'dır (Seller)
          // Eğer BU BİR HİZMETSE (Marketplace): İlanı açan SATICI'dır (Seller), giden kişi ALICI'dır (Buyer)
          seller_id: isBounty ? currentUser.uid : item.creator_id,
          seller_name: isBounty ? (userData?.firstName + ' ' + userData?.lastName) : (item.creator_name || 'Öğrenci'),
          buyer_id: isBounty ? item.creator_id : currentUser.uid,
          buyer_name: isBounty ? (item.creator_name || 'Öğrenci') : (userData?.firstName + ' ' + userData?.lastName || 'Müşteri'),
          participants: [item.creator_id, currentUser.uid],
          message_counts: { [item.creator_id]: 0, [currentUser.uid]: 0 },
          price: item.price,
          price_type: item.price_type,
          gig_type: item.type,
          created_at: serverTimestamp(),
          status: 'chatting'
        });
      }
      navigate(`/chat/${roomId}`);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    const qServices = query(collection(db, 'services'), orderBy('created_at', 'desc'));
    const unSubServices = onSnapshot(qServices, (snapshot) => {
      let list = [];
      const now = new Date();
      snapshot.forEach(doc => {
        const data = doc.data();
        const isExpired = data.expires_at && new Date(data.expires_at) < now;
        if (!isExpired) {
          list.push({ id: doc.id, ...data });
        }
      });
      setServices(list);
    });

    const qBounties = query(collection(db, 'bounties'), orderBy('created_at', 'desc'));
    const unSubBounties = onSnapshot(qBounties, (snapshot) => {
      let list = [];
      const now = new Date();
      snapshot.forEach(doc => {
        const data = doc.data();
        const isExpired = data.expires_at && new Date(data.expires_at) < now;
        if (!isExpired) {
          list.push({ id: doc.id, ...data });
        }
      });
      setBounties(list);
      setLoading(false);
    });

    return () => {
      unSubServices();
      unSubBounties();
    };
  }, []);

  const getPriceLabel = (item) => {
    if (item.price_type === 'swap') {
      return <span className="text-[17px] font-black text-inherit">1 ZK Puanı</span>;
    }
    return (
      <>
        <span className="text-[18px] font-black text-inherit">{item.price}</span>
        <span className="text-[10px] font-bold text-inherit ml-1">CGT</span>
      </>
    );
  };

  return (
    <div className="flex flex-col h-full bg-[#FAFAFC] relative overflow-hidden pb-10">

      {/* Background Animated Blobs for Premium Feel */}
      <div className={`absolute top-[-10%] left-[-20%] w-[80%] h-[30%] rounded-full mix-blend-multiply blur-[80px] animate-blob z-0 pointer-events-none transition-colors duration-700 ${activeTab === 'marketplace' ? 'bg-[#10B981]/15' : 'bg-[#6366F1]/15'}`}></div>
      <div className={`absolute top-[20%] right-[-10%] w-[70%] h-[40%] rounded-full mix-blend-multiply blur-[80px] animate-blob z-0 pointer-events-none transition-colors duration-700 ${activeTab === 'marketplace' ? 'bg-[#34D399]/10' : 'bg-[#818CF8]/10'}`} style={{ animationDelay: '2s' }}></div>

      <div className="flex-1 overflow-y-auto no-scrollbar px-5 pt-2 z-10 relative">

        {/* Header Greeting */}
        <div className="mb-8 animate-fade-in px-1 mt-6">
          <h1 className="text-[28px] font-black tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-600">
            Merhaba, {userData?.firstName || 'Gezgin'}! 👋
          </h1>
          <p className="text-gray-400 font-bold text-[10px] uppercase tracking-[0.25em] mt-2 flex items-center gap-2">
            <span className={`w-2 h-2 rounded-full animate-pulse ${activeTab === 'marketplace' ? 'bg-[#10B981]' : 'bg-[#4F46E5]'}`}></span>
            Kampüsünde Neler Oluyor?
          </p>
        </div>

        {/* Ana Segment Butonları (Marketplace vs Bounties) */}
        <div className="flex p-1.5 bg-white/70 backdrop-blur-md rounded-[24px] border border-white shadow-sm mb-6 sticky top-0 z-20">
          <button
            onClick={() => setActiveTab('marketplace')}
            className={`flex-1 py-3 px-4 rounded-[18px] text-[13px] font-extrabold transition-all duration-500 ${activeTab === 'marketplace' ? 'bg-[#059669] text-white shadow-lg shadow-emerald-500/20' : 'text-gray-400 hover:text-gray-600'}`}>
            Yetenek Pazarı
          </button>
          <button
            onClick={() => setActiveTab('bounties')}
            className={`flex-1 py-3 px-4 rounded-[18px] text-[13px] font-extrabold transition-all duration-500 ${activeTab === 'bounties' ? 'bg-[#4F46E5] text-white shadow-lg shadow-indigo-500/20' : 'text-gray-400 hover:text-gray-600'}`}>
            Görev Panosu
          </button>
        </div>

        <div className="flex justify-between items-end mb-4 px-1">
          <h2 className="text-lg font-bold text-[#111827]">
            {activeTab === 'marketplace' ? 'Kampüsteki Uzmanlar' : 'Çözüm Bekleyen İşler'}
          </h2>
        </div>

        {loading && (
          <div className="flex justify-center items-center py-20">
            <div className={`animate-spin w-10 h-10 border-[3px] rounded-full border-t-transparent ${activeTab === 'marketplace' ? 'border-[#10B981]' : 'border-[#4F46E5]'}`}></div>
          </div>
        )}

        {/* İlan Listesi */}
        {!loading && (
          <div className="flex flex-col gap-4 pb-8">
            {activeTab === 'marketplace' && services.length === 0 && (
              <div className="flex flex-col items-center justify-center py-20 px-10 bg-white/40 backdrop-blur-sm rounded-[40px] border border-dashed border-emerald-200">
                <span className="text-4xl mb-4">🍃</span>
                <p className="text-center text-emerald-900 font-black text-sm uppercase tracking-tighter">Şu an mevcut hizmet yok</p>
                <p className="text-center text-emerald-600/60 font-bold text-[11px] mt-1">İlk hizmeti sen başlatmak ister misin?</p>
              </div>
            )}
            {activeTab === 'marketplace' && services.map(gig => (
              // HİZMET VEREN KARTI (Mint Emerald Theme)
              <div key={gig.id} className="bg-[#F0FDF4] p-5 rounded-[32px] border border-[#DCFCE7] shadow-sm flex flex-col gap-3 active:scale-[0.98] transition-all relative overflow-hidden group">

                {/* Premium Effect */}
                {gig.isPremium && <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-400/10 rounded-full blur-2xl pointer-events-none"></div>}

                <div className="flex justify-between items-start z-10 relative">
                  <div className="flex items-center gap-3">
                    <div className="relative cursor-pointer active:scale-95 transition-all" 
                         onClick={() => navigate(`/user-profile/${gig.creator_id}`)}>
                      <img src={`https://api.dicebear.com/7.x/notionists/svg?seed=${gig.creator_id}&backgroundColor=DCFCE7`} alt="Avatar" className="w-12 h-12 rounded-[18px] object-cover border-2 border-white shadow-sm bg-emerald-50" />
                      {gig.isPremium && (
                        <div className="absolute -top-1.5 -right-1.5 bg-gradient-to-tr from-[#10B981] to-[#059669] rounded-full p-1 shadow-md border border-white">
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-2 w-2 text-white" viewBox="0 0 20 20" fill="currentColor">
                            <path fillRule="evenodd" d="M10 2l2.5 5.5H18l-4.5 4 1.5 6-5-3.5-5 3.5 1.5-6-4.5-4h5.5L10 2z" clipRule="evenodd" />
                          </svg>
                        </div>
                      )}
                    </div>
                    <div className="flex flex-col">
                      <div className="flex items-center gap-1.5">
                        <span className="text-[14px] font-extrabold text-[#111827] cursor-pointer hover:text-emerald-600 transition-colors"
                              onClick={() => navigate(`/user-profile/${gig.creator_id}`)}>
                          {gig.creator_name || 'Öğrenci'}
                        </span>
                        <div className="flex items-center gap-0.5 bg-white/60 px-1.5 py-0.5 rounded-md border border-[#DCFCE7]">
                          <span className="text-[10px] font-bold text-[#059669]">4.9</span>
                        </div>
                      </div>
                      <span className="text-[11px] font-bold text-[#059669] tracking-wide uppercase">{gig.university}</span>
                    </div>
                  </div>
                  <span className="px-3 py-1.5 rounded-xl bg-white/80 backdrop-blur-sm border border-[#DCFCE7] text-[9px] font-extrabold uppercase tracking-widest text-[#059669]">
                    HİZMET
                  </span>
                </div>

                <div className="mt-2 mb-1">
                  <h3 className="text-[15px] font-bold text-[#111827] leading-snug z-10 relative">{gig.title}</h3>
                  <p className="text-[#64748B] font-medium text-[12px] mt-1.5 leading-relaxed line-clamp-2 z-10 relative">
                    {gig.description}
                  </p>
                </div>

                <div className="flex justify-between items-center mt-2 pt-4 border-t border-emerald-100/50 z-10 relative">
                  <div className="flex flex-col">
                    <span className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mb-0.5">Token</span>
                    <div className="flex items-center gap-1 text-[#059669]">
                      {getPriceLabel(gig)}
                    </div>
                  </div>

                  {gig.creator_id === currentUser?.uid ? (
                    <button disabled className="bg-gray-100 text-gray-400 font-bold text-[11px] px-6 py-3 rounded-2xl uppercase tracking-widest">
                      İlanım
                    </button>
                  ) : (
                    <button
                      onClick={() => startChat(gig)}
                      className="bg-[#10B981] text-white font-bold text-[13px] px-6 py-3 rounded-2xl shadow-lg hover:bg-[#059669] transition-all">
                      Teklife Git
                    </button>
                  )}
                </div>
              </div>
            ))}

            {activeTab === 'bounties' && bounties.length === 0 && (
              <div className="flex flex-col items-center justify-center py-20 px-10 bg-white/40 backdrop-blur-sm rounded-[40px] border border-dashed border-indigo-200">
                <span className="text-4xl mb-4">🔭</span>
                <p className="text-center text-indigo-900 font-black text-sm uppercase tracking-tighter">Şu an mevcut görev yok</p>
                <p className="text-center text-indigo-600/60 font-bold text-[11px] mt-1">İhtiyacın olan bir yardım için ilan açabilirsin.</p>
              </div>
            )}
            {activeTab === 'bounties' && bounties.map(gig => (
              // DESTEK ARAYAN KARTI (Royal Indigo Theme)
              <div key={gig.id} className="bg-[#F5F3FF] p-5 rounded-[32px] border border-[#EDE9FE] shadow-sm flex flex-col gap-3 active:scale-[0.98] transition-all relative overflow-hidden group">

                <div className="flex justify-between items-start z-10 relative">
                  <div className="flex items-center gap-3">
                    <img src={`https://api.dicebear.com/7.x/notionists/svg?seed=${gig.creator_id}&backgroundColor=EDE9FE`} 
                         alt="Avatar" 
                         className="w-11 h-11 rounded-[18px] object-cover border-2 border-white shadow-sm bg-indigo-50 cursor-pointer active:scale-95 transition-all"
                         onClick={() => navigate(`/user-profile/${gig.creator_id}`)} />
                    <div className="flex flex-col">
                      <span className="text-[14px] font-extrabold text-[#111827] cursor-pointer hover:text-indigo-600 transition-colors"
                            onClick={() => navigate(`/user-profile/${gig.creator_id}`)}>
                        {gig.creator_name || 'Öğrenci'}
                      </span>
                      <span className="text-[11px] font-bold text-[#4F46E5] tracking-wide uppercase">{gig.university}</span>
                    </div>
                  </div>
                  <span className="px-3 py-1.5 rounded-xl bg-white/80 backdrop-blur-sm border border-[#EDE9FE] text-[9px] font-extrabold uppercase tracking-widest text-[#4F46E5]">
                    GÖREV
                  </span>
                </div>

                <div className="mt-2 mb-1">
                  <h3 className="text-[15px] font-bold text-[#111827] leading-snug z-10 relative">{gig.title}</h3>
                  <p className="text-[#64748B] font-medium text-[12px] mt-1.5 leading-relaxed line-clamp-2 z-10 relative">
                    {gig.description}
                  </p>
                </div>

                <div className="flex items-center gap-2 mt-1">
                  {gig.deadline && (
                    <div className="bg-white/60 px-2.5 py-1.5 rounded-xl border border-[#EDE9FE] flex items-center gap-1.5">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <span className="text-[10px] font-extrabold text-[#4F46E5] uppercase tracking-widest">Teslim: {new Date(gig.deadline).toLocaleDateString('tr-TR')}</span>
                    </div>
                  )}
                </div>

                <div className="flex justify-between items-center mt-2 pt-4 border-t border-indigo-100/50 z-10 relative">
                  <div className="flex flex-col">
                    <span className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mb-0.5">Ödül Bütçesi</span>
                    <div className="flex items-center gap-1 text-[#4F46E5]">
                      {getPriceLabel(gig)}
                    </div>
                  </div>

                  {gig.creator_id === currentUser?.uid ? (
                    <button disabled className="bg-gray-100 text-gray-400 font-bold text-[11px] px-6 py-3 rounded-2xl uppercase tracking-widest">
                      İlanım
                    </button>
                  ) : (
                    <button
                      onClick={() => startChat(gig)}
                      className="bg-[#4F46E5] text-white font-bold text-[13px] px-6 py-3 rounded-2xl shadow-lg hover:bg-[#4338CA] transition-all">
                      Göreve Git
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

      </div>
    </div>
  );
}
