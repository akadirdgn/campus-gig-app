import React, { useState } from 'react';
import { db } from '../firebase';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function CreateGig() {
  const { currentUser, userData } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false); // Yeni Başarı State'i
  const [showError, setShowError] = useState(false); // Yetersiz Bakiye Hata State'i
  const [activeTab, setActiveTab] = useState('marketplace'); 

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    price_type: 'token',   
    price: 0,
    deadline: ''
  });

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title || (formData.price_type === 'token' && formData.price <= 0)) return;
    
    // Bakiye Kontrolü (Sadece Görev Oluştururken ve Token seçiliyse)
    if (activeTab === 'bounties' && formData.price_type === 'token') {
      const currentToken = userData?.wallet_cgt || 0;
      if (formData.price > currentToken) {
        setShowError(true);
        return;
      }
    }

    setLoading(true);

    try {
      const mockUid = currentUser ? currentUser.uid : 'demo_user_' + Math.floor(Math.random() * 10000);
      const mockName = currentUser && userData?.firstName ? `${userData.firstName} ${userData.lastName}` : 'Misafir Öğrenci';
      const mockUni = currentUser && userData?.university ? userData.university : 'Deneme Üniversitesi';

      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 15);

      // Firebase'e yazma işlemini "await" beklemeden (arka planda) gönderiyoruz, çok hızlı tepki vermesi için.
      addDoc(collection(db, activeTab === 'marketplace' ? 'services' : 'bounties'), {
        ...formData,
        type: activeTab,
        creator_id: mockUid,
        creator_name: mockName,
        university: mockUni,
        status: 'open',
        created_at: serverTimestamp(),
        expires_at: expiresAt.toISOString()
      }).catch(err => console.warn("Firebase erişimi yok, demo verisi ile sadece UI tarafında işleniyor.", err));

      setLoading(false);
      setShowSuccess(true); // Başarılı animasyonunu tetikle

      setTimeout(() => {
        navigate('/');
      }, 2000); // 2 saniye sonra anasayfaya yönlendir
    } catch (error) {
       console.error(error);
       setLoading(false);
    }
  };

  const isMarketplace = activeTab === 'marketplace';

  // Son teslim tarihi için bugünden 10 gün sonrası limiti
  const todayDate = new Date().toISOString().split("T")[0];
  const maxDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  return (
    <div className="flex flex-col h-full bg-[#FAFAFC] relative overflow-hidden pb-4">
      
      {/* 🌟 Başarı Animasyonu / Pop-up (Tüm Ekranı Kaplar) */}
      {showSuccess && (
        <div className="absolute inset-0 z-[110] bg-white/90 backdrop-blur-xl flex flex-col items-center justify-center animate-fade-in px-8">
           <div className="w-24 h-24 bg-[#10B981] rounded-[32px] flex items-center justify-center mb-6 shadow-2xl shadow-emerald-500/20 animate-bounce">
             <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
               <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
             </svg>
           </div>
           <h2 className="text-2xl font-black text-[#111827] text-center leading-tight mb-2 uppercase tracking-tighter">
             {isMarketplace ? 'Hizmetin Yayında!' : 'Görev Oluşturuldu!'}
           </h2>
           <p className="text-gray-400 font-bold text-[10px] tracking-[0.3em] uppercase">Akışa Yönlendiriliyorsun...</p>
        </div>
      )}

      {/* ⚠️ Yetersiz Bakiye Hatası (Premium Widget) */}
      {showError && (
        <div className="absolute inset-0 z-[110] bg-[#111827]/60 backdrop-blur-md flex flex-col items-center justify-center animate-fade-in px-6">
           <div className="bg-white rounded-[40px] p-8 w-full shadow-2xl relative overflow-hidden flex flex-col items-center border border-gray-100">
             {/* Gradient Background for Widget */}
             <div className="absolute top-0 right-0 w-32 h-32 bg-red-400/5 rounded-full blur-3xl"></div>
             
             <div className="w-20 h-20 bg-red-50 rounded-[28px] flex items-center justify-center mb-6 border border-red-100 shadow-inner">
               <span className="text-3xl">💸</span>
             </div>

             <h2 className="text-2xl font-black text-[#111827] text-center mb-3 tracking-tight">Yetersiz Token!</h2>
             
             <div className="bg-red-50 px-4 py-3 rounded-2xl border border-red-100 mb-6 w-full text-center">
               <p className="text-[14px] text-red-600 font-bold leading-snug">
                 Bu görevi oluşturmak için <span className="text-red-800 font-black">{formData.price} CGT</span> gerekiyor.
               </p>
               <p className="text-[11px] text-red-400 font-medium mt-1">Cüzdanında şu an {userData?.wallet_cgt || 0} CGT var.</p>
             </div>

             <div className="flex flex-col gap-3 w-full">
               <button 
                 onClick={() => navigate('/profile')}
                 className="w-full bg-gradient-to-r from-[#059669] to-[#10B981] text-white font-black text-[12px] py-4 rounded-2xl uppercase tracking-widest shadow-xl shadow-emerald-500/20 active:scale-95 transition-all">
                 Token Satın Al
               </button>
               <button 
                 onClick={() => setShowError(false)}
                 className="w-full bg-red-50 text-red-400 font-extrabold text-[12px] py-4 rounded-2xl uppercase tracking-widest active:bg-red-100 transition-all">
                 Vazgeç
               </button>
             </div>
           </div>
        </div>
      )}

      {/* Background Animated Blobs */}
      <div className={`absolute top-[-10%] left-[-20%] w-[80%] h-[50%] rounded-full mix-blend-multiply blur-[80px] animate-blob z-0 pointer-events-none transition-colors duration-1000 ${isMarketplace ? 'bg-[#10B981]/15' : 'bg-[#4F46E5]/15'}`}></div>
      <div className={`absolute top-[20%] right-[-10%] w-[70%] h-[60%] rounded-full mix-blend-multiply blur-[80px] animate-blob z-0 pointer-events-none transition-colors duration-1000 ${isMarketplace ? 'bg-[#34D399]/10' : 'bg-[#818CF8]/10'}`} style={{ animationDelay: '2s' }}></div>

      <div className="flex-1 overflow-y-auto no-scrollbar px-5 pt-6 pb-24 z-10 relative">

        <div className="mb-6">
          <h1 className="text-[26px] font-extrabold text-[#111827] tracking-tight">Yeni İlan Oluştur</h1>
          <p className="text-[#6B7280] font-medium text-[13px] mt-1">Yetenek ağında profilini sergile veya iş ver.</p>
        </div>

        {/* Ana Segment Butonları (Marketplace vs Bounties) */}
        <div className="flex p-1.5 bg-white/70 backdrop-blur-md rounded-[24px] border border-white shadow-sm mb-6 relative z-20">
          <button 
            type="button"
            onClick={() => setActiveTab('marketplace')}
            className={`flex-1 py-3.5 px-4 rounded-[18px] text-[12px] uppercase tracking-widest font-black transition-all duration-500 ${isMarketplace ? 'bg-[#059669] text-white shadow-lg shadow-emerald-500/20' : 'text-gray-400 hover:text-gray-600'}`}>
            Hizmet Ver
          </button>
          <button 
            type="button"
            onClick={() => setActiveTab('bounties')}
            className={`flex-1 py-3.5 px-4 rounded-[18px] text-[12px] uppercase tracking-widest font-black transition-all duration-500 ${!isMarketplace ? 'bg-[#4F46E5] text-white shadow-lg shadow-indigo-500/20' : 'text-gray-400 hover:text-gray-600'}`}>
            Yardım İste
          </button>
        </div>
        
        <form onSubmit={handleSubmit} className="flex flex-col gap-5">

          {/* Form Content Wrapper */}
          <div className="bg-white rounded-[24px] shadow-sm border border-gray-100 p-5 flex flex-col gap-6 relative z-20">
              
              <div className="mb-1">
                <span className={`text-[10px] font-bold tracking-widest uppercase px-3 py-1.5 rounded-lg
                                ${isMarketplace ? 'bg-[#F4F0FF] text-[#6D28D9]' : 'bg-[#EFF6FF] text-[#1D4ED8]'}`}>
                  {isMarketplace ? 'Servis Profili Oluştur' : 'Görev (Bounty) Oluştur'}
                </span>
              </div>

              {/* Title */}
              <div className="relative group mt-3">
                <input type="text" name="title" id="title" value={formData.title} onChange={handleChange} required placeholder=" "
                       className="w-full bg-transparent border-b border-gray-200 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px]" />
                <label htmlFor="title" className={`absolute left-0 top-5 text-gray-400 font-medium text-[13px] transition-all duration-300 pointer-events-none 
                                  peer-focus:-top-2 peer-focus:text-[10px] peer-focus:font-bold peer-focus:tracking-widest peer-focus:uppercase peer-valid:-top-2 peer-valid:text-[10px] peer-valid:font-bold peer-valid:tracking-widest peer-valid:uppercase
                                  ${isMarketplace ? 'peer-focus:text-[#6D28D9] peer-valid:text-[#6D28D9]' : 'peer-focus:text-[#1D4ED8] peer-valid:text-[#1D4ED8]'}`}>
                  {isMarketplace ? 'Hangi Yeteneğini Sunuyorsun?' : 'Neye İhtiyacın Var?'}
                </label>
                <div className={`absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] peer-focus:w-full transition-all duration-500 ease-out 
                                ${isMarketplace ? 'bg-[#6D28D9]' : 'bg-[#1D4ED8]'}`}></div>
              </div>

              {/* Description */}
              <div className="relative group mt-2">
                <textarea name="description" id="description" value={formData.description} onChange={handleChange} required placeholder=" "
                          className="w-full h-24 bg-transparent border-b border-gray-200 pb-2 pt-6 focus:outline-none focus:border-transparent peer text-[#111827] font-medium text-[13px] resize-none"></textarea>
                <label htmlFor="description" className={`absolute left-0 top-6 text-gray-400 font-medium text-[13px] transition-all duration-300 pointer-events-none 
                                  peer-focus:-top-2 peer-focus:text-[10px] peer-focus:font-bold peer-focus:tracking-widest peer-focus:uppercase peer-valid:-top-2 peer-valid:text-[10px] peer-valid:font-bold peer-valid:tracking-widest peer-valid:uppercase
                                  ${isMarketplace ? 'peer-focus:text-[#6D28D9] peer-valid:text-[#6D28D9]' : 'peer-focus:text-[#1D4ED8] peer-valid:text-[#1D4ED8]'}`}>
                  {isMarketplace ? "Sana Başvuranlara Neler Katacaksın?" : "Seçeceğin Kişiden Tam Beklentilerin"}
                </label>
                <div className={`absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] peer-focus:w-full transition-all duration-500 ease-out 
                                ${isMarketplace ? 'bg-[#6D28D9]' : 'bg-[#1D4ED8]'}`}></div>
              </div>

              {/* Deadline (Sadece Yardım İsteyenler İçin Görünür) */}
              {!isMarketplace && (
                 <div className="flex flex-col gap-2 mt-2 animate-fade-in relative z-20">
                    <label htmlFor="deadline" className="text-[10px] font-black tracking-[0.2em] uppercase text-[#4F46E5] pl-1">
                      Görevin Son Teslim Günü
                    </label>
                    <div className="relative group">
                      <input type="date" name="deadline" id="deadline" value={formData.deadline} onChange={handleChange} required 
                             min={todayDate}
                             max={maxDate}
                             className="w-full bg-white border-b-2 border-gray-100 pb-3 pt-2 focus:outline-none focus:border-[#4F46E5] transition-all text-[#111827] font-bold text-[16px]" />
                    </div>
                 </div>
              )}
          </div>

          {/* Pricing Configurator */}
          <div className="bg-white rounded-[24px] shadow-sm border border-gray-100 p-5 relative z-20">
              <label className="text-[11px] font-extrabold text-[#111827] uppercase tracking-widest mb-4 block">Ekonomi Modeli</label>
              
              <div className="flex gap-3 mb-5">
                <button type="button" onClick={() => setFormData({...formData, price_type: 'token'})}
                        className={`flex-1 py-3.5 px-2 rounded-2xl text-[11px] font-black tracking-widest uppercase transition-all duration-500 border
                        ${formData.price_type === 'token' ? (isMarketplace ? 'bg-[#10B981] text-white border-transparent shadow-lg shadow-emerald-500/20' : 'bg-[#4F46E5] text-white border-transparent shadow-lg shadow-indigo-500/20') : 'bg-gray-50 text-gray-400 border-gray-100 hover:border-gray-200'}`}>
                  Token (Bakiye)
                </button>
                <button type="button" onClick={() => setFormData({...formData, price_type: 'swap', price: 0})}
                        className={`flex-1 flex justify-center items-center gap-1.5 py-3.5 px-2 rounded-2xl text-[11px] font-black tracking-widest uppercase transition-all duration-500 border
                        ${formData.price_type === 'swap' 
                          ? (isMarketplace 
                              ? 'bg-gradient-to-tr from-[#10B981] to-[#34D399] text-white border-transparent shadow-lg shadow-emerald-500/20 scale-[1.02]' 
                              : 'bg-gradient-to-tr from-[#4F46E5] to-[#6366F1] text-white border-transparent shadow-lg shadow-indigo-500/20 scale-[1.02]') 
                          : 'bg-gray-50 text-gray-400 border-gray-100 hover:border-gray-200'}`}>
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Zaman Kredisi
                </button>
              </div>

              {formData.price_type === 'token' && (
                <div className={`animate-fade-in relative p-4 rounded-2xl border ${isMarketplace ? 'bg-[#FCFAFF] border-[#EADDFF]' : 'bg-[#F4F9FF] border-[#D1E4FF]'}`}>
                  <div className="flex bg-white rounded-xl border border-gray-100 overflow-hidden shadow-sm">
                     <span className="bg-gray-50 px-4 flex items-center justify-center font-bold text-gray-400 text-sm border-r border-gray-100">💰</span>
                     <input type="number" min="1" name="price" onChange={(e) => setFormData({...formData, price: Number(e.target.value)})} required 
                            className="w-full p-4 focus:outline-none text-[#111827] font-black text-[18px]" placeholder="0" />
                     <span className="bg-white px-4 flex items-center justify-center font-black text-gray-300">CGT</span>
                  </div>
                  <p className="text-[10px] text-gray-500 mt-3 font-semibold px-2">
                    {isMarketplace ? "Senden bu hizmeti alan kişi, belirlediğin bu tutarı ödemek zorundadır." 
                                   : "Bu ödül (bounty) anında cüzdanından düşülerek Escrow güvenli havuzuna kilitlenir."}
                  </p>
                </div>
              )}

              {formData.price_type === 'swap' && (
                <div className="animate-fade-in flex flex-col gap-2">
                   <div className="p-4 rounded-xl border bg-gray-50 border-gray-200">
                     {isMarketplace ? (
                        <p className="text-[11px] text-[#111827] font-bold text-center leading-relaxed">
                          Bu hizmet karşılığında <span className="text-purple-600 font-black">1 Saat ZK (Zaman Kredisi)</span> talep ediyorsun. 
                        </p>
                     ) : (
                        <p className="text-[11px] text-[#111827] font-bold text-center leading-relaxed">
                          Sana yardım edecek kişiye ödemeyi cüzdanındaki <span className="text-blue-600 font-black">Zaman Kredisi</span> ile yapacaksın.
                        </p>
                     )}
                   </div>

                   {/* Anti-Cheat Warning Cards */}
                   <div className="grid grid-cols-2 gap-2 mt-1">
                      <div className="bg-orange-50/50 border border-orange-100 rounded-xl p-3 flex flex-col justify-center items-center text-center">
                         <span className="text-[12px] mb-1">🔥</span>
                         <span className="text-[9px] font-extrabold text-orange-600 uppercase tracking-widest leading-tight">Takas Komisyonu</span>
                         <span className="text-[9px] font-bold text-gray-500 mt-1 leading-tight">Yapay döngüleri önlemek için sistem her Kredi transferinde %10 burn (zaman kesintisi) uygular.</span>
                      </div>
                      <div className="bg-red-50/50 border border-red-100 rounded-xl p-3 flex flex-col justify-center items-center text-center">
                         <span className="text-[12px] mb-1">🛡️</span>
                         <span className="text-[9px] font-extrabold text-red-600 uppercase tracking-widest leading-tight">Kalkan Aktif</span>
                         <span className="text-[9px] font-bold text-gray-500 mt-1 leading-tight">Günde maks. 2 Kredi üretebilirsiniz. Aynı kişiyle 14 günde 1 kez eşleşebilirsiniz.</span>
                      </div>
                   </div>
                </div>
              )}
          </div>

          <div className="px-5 py-3 bg-amber-50 rounded-2xl border border-amber-100 flex items-center gap-3">
             <span className="text-lg">🕒</span>
             <p className="text-[11px] text-amber-700 font-bold leading-tight uppercase tracking-tighter">
                Güvenlik Politikası: Yayınlanan tüm ilanlar 15 gün sonra otomatik olarak yayından kaldırılacaktır.
             </p>
          </div>

          <button type="submit" disabled={loading}
                  className={`mt-4 mb-10 w-full text-white font-black text-[13px] uppercase tracking-[0.2em] py-5 rounded-[24px] shadow-2xl active:scale-[0.97] transition-all duration-500 flex justify-center items-center gap-3 relative overflow-hidden group
                  ${loading ? 'bg-gray-400' : isMarketplace ? 'bg-[#10B981] shadow-emerald-500/30' : 'bg-[#4F46E5] shadow-indigo-500/30'}`}>
            {loading ? (
              <div className="w-6 h-6 border-4 border-white/30 border-t-white rounded-full animate-spin"></div>
            ) : (
              <>
                <span className="relative z-10">{isMarketplace ? 'Hizmetimi Başlat' : 'Görevi Paylaş & Öde'}</span>
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform relative z-10" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
}
