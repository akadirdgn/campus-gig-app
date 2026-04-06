import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { db, auth } from '../firebase';
import { collection, query, orderBy, onSnapshot, addDoc, doc, updateDoc, serverTimestamp, getDoc, arrayUnion, increment, runTransaction, Timestamp, setDoc } from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';

export default function Chat() {
  const { roomId } = useParams();
  const { currentUser, userData } = useAuth();
  const navigate = useNavigate();
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [roomData, setRoomData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [modalNotice, setModalNotice] = useState(null); // { title: '', text: '', icon: '', type: 'success' | 'error' }
  const [confirmModal, setConfirmModal] = useState(null); // { title: '', text: '', onConfirm: fn }
  const [pinInput, setPinInput] = useState('');
  const [customLink, setCustomLink] = useState('');
  const [sessionTimer, setSessionTimer] = useState(0);
  const [rating, setRating] = useState(0);
  const [reviewText, setReviewText] = useState('');
  const [reviewSent, setReviewSent] = useState(false);
  const messagesEndRef = useRef(null);

  // Mesaj Hakkı: Son 12 saatteki metin mesajlarını sayar (Kayan Pencere Mantığı)
  const myMessageCount = messages.filter(m =>
    m.sender_id === currentUser?.uid &&
    m.type === 'text' &&
    m.created_at &&
    (Date.now() - m.created_at.toMillis() < 12 * 60 * 60 * 1000)
  ).length;

  const isSeller = roomData?.seller_id === currentUser?.uid;

  useEffect(() => {
    if (!roomId) return;

    // 1. Oda Verilerini Çek
    const unSubRoom = onSnapshot(doc(db, 'chat_rooms', roomId), (docSnap) => {
      if (docSnap.exists()) setRoomData(docSnap.data());
    });

    // 2. Mesajları Çek
    const q = query(collection(db, 'chat_rooms', roomId, 'messages'), orderBy('created_at', 'asc'));
    const unSubMsgs = onSnapshot(q, (snapshot) => {
      let list = [];
      snapshot.forEach(doc => list.push({ id: doc.id, ...doc.data() }));
      setMessages(list);
      setTimeout(() => messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 100);
    });

    // 3. Okunmamış işaretini temizle
    const clearUnread = async () => {
      try {
        const roomRef = doc(db, 'chat_rooms', roomId);
        const roomSnap = await getDoc(roomRef);
        if (roomSnap.exists()) {
          const data = roomSnap.data();
          if (data.unread_by?.includes(currentUser.uid)) {
            await updateDoc(roomRef, {
              unread_by: data.unread_by.filter(id => id !== currentUser.uid)
            });
          }
        }
      } catch (err) {
        console.error("Okunmamış durumu güncellenemedi:", err);
      }
    };
    clearUnread();

    return () => { unSubRoom(); unSubMsgs(); };
  }, [roomId, currentUser.uid]);

  const sendMessage = async (e, type = 'text') => {
    if (e) e.preventDefault();
    if (type === 'text' && (!newMessage.trim() || newMessage.length > 140)) return;

    // Mesaj hakkı kontrolü (Teklifler bu sınırı harcamaz)
    if (type === 'text' && myMessageCount >= 5) {
      setModalNotice({
        title: "Limit Doldu",
        text: "Bu görüşme için günlük mesaj hakkınız (5) dolmuştur. Yarın tekrar yazabilirsiniz.",
        icon: "🚫",
        type: "error"
      });
      return;
    }

    // Teklif Cooldown Kontrolü (1 Saat)
    if (type === 'offer') {
      const lastOffer = roomData?.last_offer_at?.toDate() || 0;
      const oneHour = 60 * 60 * 1000;
      if (Date.now() - lastOffer < oneHour) {
        const diff = Math.ceil((oneHour - (Date.now() - lastOffer)) / 60000);
        setModalNotice({
          title: "Biraz Beklemelisiniz",
          text: `İşlem güvenliği için yeni bir teklif göndermeden önce ${diff} dakika daha beklemeniz gerekiyor.`,
          icon: "⏳",
          type: "error"
        });
        return;
      }
    }

    try {
      // 1. Mesajı Ekle
      await addDoc(collection(db, 'chat_rooms', roomId, 'messages'), {
        sender_id: currentUser.uid,
        sender_name: userData?.firstName || 'Öğrenci',
        content: type === 'offer' ? 'ÖDEME TALEBİ: Hizmet onayı bekleniyor.' : newMessage,
        type: type, // 'text' or 'offer'
        status: type === 'offer' ? 'pending' : null,
        created_at: serverTimestamp()
      });

      // 2. Oda Metaverilerini Güncelle (Okunmamış bilgisi dahil)
      const otherParticipantId = roomData.participants.find(id => id !== currentUser.uid);
      
      const updateData = {
        last_message: type === 'offer' ? 'Ödeme Talebi gönderildi.' : newMessage,
        last_sender_id: currentUser.uid,
        last_message_at: serverTimestamp(),
        unread_by: [otherParticipantId] // Karşı taraf okumadı
      };

      if (type === 'offer') {
        updateData.last_offer_at = serverTimestamp();
        updateData.status = 'waiting_approval';
      }

      await updateDoc(doc(db, 'chat_rooms', roomId), updateData);

      setNewMessage('');
    } catch (err) {
      console.error(err);
      setModalNotice({
        title: "Gönderilemedi",
        text: "Mesajınız iletilemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.",
        icon: "⚠️",
        type: "error"
      });
    }
  };

  const handleOfferResponse = async (response, msgId) => {
    if (response === 'NO') {
      setConfirmModal({
        title: "Teklif Reddedilsin mi?",
        text: "Bu teklifi reddettiğinizde satıcı yeni bir teklif gönderebilir. Emin misiniz?",
        onConfirm: async () => {
          await updateDoc(doc(db, 'chat_rooms', roomId, 'messages', msgId), { status: 'rejected' });
          await updateDoc(doc(db, 'chat_rooms', roomId), { status: 'chatting' });
          setConfirmModal(null);
          setModalNotice({
            title: "Teklif Reddedildi",
            text: "Satıcıdan yeni bir teklif isteyebilirsiniz.",
            icon: "❌",
            type: "error"
          });
        }
      });
      return;
    }

    setLoading(true);
    try {
      const buyerId = currentUser.uid;
      const sellerId = roomData.seller_id;
      const amount = Number(roomData.price);
      const priceType = roomData.price_type;

      if (buyerId === sellerId) throw new Error("Kendi ilanınızı satın alamazsınız.");

      await runTransaction(db, async (transaction) => {
        const buyerRef = doc(db, 'users', buyerId);
        const buyerDoc = await transaction.get(buyerRef);
        if (!buyerDoc.exists()) throw new Error("Profil bulunamadı.");
        
        const currentBalance = Number(buyerDoc.data()[priceType === 'swap' ? 'wallet_time_credit' : 'wallet_cgt'] || 0);

        if (currentBalance < amount) {
          setModalNotice({
            title: "Yetersiz Bakiye!",
            text: `Bu işlem için ${amount} ${priceType === 'swap' ? 'ZK' : 'CGT'} gerekiyor. Mevcut bakiyeniz: ${currentBalance}`,
            icon: "💸",
            type: "error"
          });
          throw new Error("insufficent_balance");
        }

        // 1. Alıcıdan parayı düş
        const balanceField = priceType === 'swap' ? 'wallet_time_credit' : 'wallet_cgt';
        transaction.update(buyerRef, { [balanceField]: increment(-amount) });

        // 2. İşlem kaydı oluştur
        const transRef = doc(collection(db, 'transactions'));
        const transactionId = transRef.id;
        transaction.set(transRef, {
          gig_id: roomData.gig_id,
          buyer_id: buyerId,
          seller_id: sellerId,
          amount: amount,
          price_type: priceType,
          status: "escrow",
          created_at: serverTimestamp()
        });

        // 3. Sohbet odasını güncelle
        transaction.update(doc(db, 'chat_rooms', roomId), {
          active_transaction_id: transactionId,
          status: 'escrow_locked'
        });

        // 4. İletiyi güncelle
        transaction.update(doc(db, 'chat_rooms', roomId, 'messages', msgId), { status: 'accepted' });
      });

      setModalNotice({
        title: isSeller ? "Ödeme Alındı! 💰" : "Ödeme Kilitlendi! 🛡️",
        text: isSeller 
          ? "Harika! Ödemeniz güvenli havuza girdi. Artık işe/derse başlayabilirsiniz." 
          : "Tebrikler! CGT güvenli havuzda donduruldu. İş bitince onaylamayı unutma.",
        icon: isSeller ? "✅" : "🛡️",
        type: "success"
      });
    } catch (err) {
      if (err.message !== "insufficent_balance") {
        console.error(err);
        alert("İşlem hatası: " + err.message);
      }
    } finally {
      setLoading(false);
    }
  };

  const [sessionIntervalId, setSessionIntervalId] = useState(null);

  // 1. PIN Üret ve Alıcıya Göster
  const handleInitiateSession = async () => {
    setLoading(true);
    try {
      const pin = Math.floor(1000 + Math.random() * 9000).toString();
      await updateDoc(doc(db, 'chat_rooms', roomId), {
        session_status: 'awaiting_pin',
        session_pin: pin,
        session_start_request_at: serverTimestamp()
      });

      await addDoc(collection(db, 'chat_rooms', roomId, 'messages'), {
        sender_id: currentUser.uid,
        sender_name: userData?.firstName || 'Seller',
        content: "Dersi başlatmak istiyorum. Lütfen ekranınızdaki PIN kodunu benimle paylaşın.",
        type: 'system_info',
        created_at: serverTimestamp()
      });
    } catch (err) {
      console.error(err);
      setModalNotice({
        title: "Başlatılamadı",
        text: "Oturum oluşturulurken bir sorun oluştu: " + err.message,
        icon: "⚠️",
        type: "error"
      });
    } finally {
      setLoading(false);
    }
  };

  // 2. Satıcı PIN'i Doğrular ve Dersi Başlatır
  const handleVerifyPin = async () => {
    if (pinInput !== roomData?.session_pin) {
      setModalNotice({
        title: "Hatalı Kod",
        text: "Girdiğiniz PIN kodu eşleşmiyor. Lütfen karşı taraftan doğru kodu isteyin.",
        icon: "🔐",
        type: "error"
      });
      return;
    }

    setLoading(true);
    try {
      // Eğer satıcı link girmemişse otomatik Jitsi linki üret
      const finalLink = customLink.trim() || `https://meet.jit.si/CampusGig-${roomId}-${Math.random().toString(36).substring(7)}`;

      await updateDoc(doc(db, 'chat_rooms', roomId), {
        session_status: 'in_progress',
        session_started_at: serverTimestamp(),
        session_pin: null, // PIN kullanıldı, temizle
        session_meeting_link: finalLink
      });

      setPinInput('');
      setCustomLink('');
      setModalNotice({
        title: "Ders Başladı!",
        text: "Güvenli el sıkışma sağlandı. Odalar hazır.",
        icon: "⏱️",
        type: "success"
      });
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  // Timer Efekti
  useEffect(() => {
    let interval;
    if (roomData?.session_status === 'in_progress' && roomData?.session_started_at) {
      interval = setInterval(() => {
        const start = roomData.session_started_at.toDate().getTime();
        const now = new Date().getTime();
        setSessionTimer(Math.floor((now - start) / 1000));
      }, 1000);
    } else {
      setSessionTimer(0);
    }
    return () => clearInterval(interval);
  }, [roomData?.session_status, roomData?.session_started_at]);

  const handleSubmitWork = async (proofType, detail) => {
    if (!roomData?.active_transaction_id) return;
    setLoading(true);
    try {
      let workProof = {};
      if (proofType === 'lesson') {
        workProof = {
          type: 'lesson',
          duration: sessionTimer,
          started_at: roomData.session_started_at.toDate().toISOString(),
          ended_at: new Date().toISOString(),
          meeting_link: roomData.session_meeting_link || ''
        };
      } else {
        workProof = {
          type: 'delivery',
          note: detail || "Dosya/Not teslim edildi.",
          timestamp: new Date().toISOString()
        };
      }

      const autoApproveDate = new Date();
      autoApproveDate.setHours(autoApproveDate.getHours() + 48);

      await runTransaction(db, async (transaction) => {
        transaction.update(doc(db, 'chat_rooms', roomId), {
          status: 'awaiting_verification',
          session_status: 'completed',
          work_proof: workProof,
          submitted_at: serverTimestamp()
        });

        transaction.update(doc(db, 'transactions', roomData.active_transaction_id), {
          auto_approve_at: Timestamp.fromDate(autoApproveDate),
          work_submitted: true,
          work_proof: workProof
        });
      });

      await addDoc(collection(db, 'chat_rooms', roomId, 'messages'), {
        sender_id: currentUser.uid,
        sender_name: userData?.firstName || 'Seller',
        content: `İŞ TESLİM EDİLDİ: ${proofType === 'lesson' ? `${Math.floor(sessionTimer / 60)} dk eğitim oturumu özeti.` : 'Görev dosyaları ve notlar iletildi.'}`,
        type: 'system_info',
        subtype: 'delivery',
        meeting_link: proofType === 'lesson' ? roomData.session_meeting_link : null,
        created_at: serverTimestamp()
      });

      setModalNotice({
        title: "Oturum Tamamlandı!",
        text: "Resmi iş kanıtı oluşturuldu ve alıcıya sunuldu.",
        icon: "✅",
        type: "success"
      });
    } catch (err) {
      console.error(err);
      alert("Hata: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDispute = async () => {
    const reason = prompt("Lütfen itiraz nedeninizi kısaca açıklayın:");
    if (!reason) return;

    setLoading(true);
    try {
      await updateDoc(doc(db, 'transactions', roomData.active_transaction_id), {
        status: 'disputed',
        dispute_reason: reason,
        disputed_by: currentUser.uid,
        disputed_at: serverTimestamp()
      });
      await updateDoc(doc(db, 'chat_rooms', roomId), { status: 'disputed' });
      setModalNotice({
        title: "İtiraz Kaydedildi",
        text: "Talebin moderatör ekibimize iletildi. En kısa sürede inceleme yapılacaktır.",
        icon: "⚖️",
        type: "success"
      });

      // Sohbet geçmişine resmi bildirim ekle
      await addDoc(collection(db, 'chat_rooms', roomId, 'messages'), {
        sender_id: currentUser.uid,
        sender_name: 'Sistem',
        content: `İŞLEM DURDURULDU: ${reason}`,
        type: 'system_info',
        subtype: 'dispute',
        created_at: serverTimestamp()
      });
    } catch (err) {
      console.error(err);
      alert("Hata: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleApproveJob = async () => {
    if (!roomData?.active_transaction_id) return;

    const isBuyer = roomData.buyer_id === currentUser.uid;
    const isSeller = roomData.seller_id === currentUser.uid;

    if (isBuyer) {
      setConfirmModal({
        title: "Ödemeyi Onayla",
        text: "Sunulan kanıtları incelediniz mi? İşin tamamlandığını ve ödemeyi satıcıya aktarmayı onaylıyor musunuz?",
        onConfirm: () => processApproval()
      });
    } else {
      processApproval();
    }
  };

  const processApproval = async () => {
    setConfirmModal(null);
    setLoading(true);
    try {
      await runTransaction(db, async (transaction) => {
        const transRef = doc(db, 'transactions', roomData.active_transaction_id);
        const transDoc = await transaction.get(transRef);
        if (!transDoc.exists()) throw new Error("İşlem bulunamadı.");

        const transData = transDoc.data();
        if (transData.status === "completed") throw new Error("Zaten tamamlanmış.");

        // KONTROL: Satıcı çekmek istiyorsa 48 saat dolmuş mu?
        if (isSeller) {
          const now = new Date();
          const autoAt = transData.auto_approve_at?.toDate();
          if (!autoAt || now < autoAt) {
            throw new Error("Otomatik onay süresi (48 saat) henüz dolmadı.");
          }
        }

        const amount = transData.amount;
        const systemFee = amount * 0.10;
        const amountToSeller = amount - systemFee;

        // 1. Satıcıya ekle
        const sellerRef = doc(db, 'users', transData.seller_id);
        const balanceField = transData.price_type === 'swap' ? 'wallet_time_credit' : 'wallet_cgt';
        transaction.update(sellerRef, { [balanceField]: increment(amountToSeller) });

        // 2. İşlemi bitir
        transaction.update(transRef, {
          status: "completed",
          completed_at: serverTimestamp(),
          fee_deducted: systemFee
        });

        // 3. Odayı güncelle
        transaction.update(doc(db, 'chat_rooms', roomId), {
          status: 'completed',
          active_transaction_id: null
        });

        // 4. Sistem hesabına komisyon
        const systemRef = doc(db, 'system', 'wallet');
        transaction.set(systemRef, { total_fees: increment(systemFee) }, { merge: true });
      });

      setModalNotice({
        title: "İşlem Tamamlandı!",
        text: isSeller 
          ? "Tebrikler! Ödeme bakiyenize başarıyla aktarıldı." 
          : "İşlemi onayladınız. Bakiye satıcıya gönderildi. Teşekkürler!",
        icon: "🏆",
        type: "success"
      });

      // Sohbet geçmişine resmi bildirim ekle
      await addDoc(collection(db, 'chat_rooms', roomId, 'messages'), {
        sender_id: currentUser.uid,
        sender_name: 'Sistem',
        content: "ÖDEME ONAYLANDI: İşlem başarıyla tamamlandı ve bakiye aktarıldı.",
        type: 'system_info',
        subtype: 'approval',
        created_at: serverTimestamp()
      });
    } catch (err) {
      console.error(err);
      setModalNotice({
        title: "İşlem Hatası",
        text: "Onay işlemi sırasında bir sorun oluştu: " + err.message,
        icon: "⚠️",
        type: "error"
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSendReview = async () => {
    if (rating === 0) {
      setModalNotice({
        title: "Eksik Puan",
        text: "Lütfen deneyiminizi değerlendirmek için bir yıldız seçin.",
        icon: "⭐",
        type: "error"
      });
      return;
    }
    setLoading(true);
    try {
      // 1. Yorumu Kaydet
      await addDoc(collection(db, 'reviews'), {
        room_id: roomId,
        writer_id: currentUser.uid,
        writer_name: userData?.firstName || 'Anonim',
        target_id: roomData.seller_id,
        rating: rating,
        comment: reviewText,
        created_at: serverTimestamp(),
        gig_title: roomData.gig_title
      });

      // 2. Odayı Güncelle
      await updateDoc(doc(db, 'chat_rooms', roomId), {
        review_submitted: true
      });

      setReviewSent(true);
      setModalNotice({
        title: "Teşekkürler! ❤️",
        text: "Değerlendirmen başarıyla kaydedildi.",
        icon: "🌟",
        type: "success"
      });
    } catch (err) {
      console.error(err);
      setModalNotice({
        title: "Gönderilemedi",
        text: "Değerlendirmeniz kaydedilirken bir hata oluştu: " + err.message,
        icon: "❌",
        type: "error"
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#F8F9FB] relative">

      {/* Sade ve Minimalist Confirm Modal */}
      {confirmModal && (
        <div className="fixed inset-0 z-[110] flex items-center justify-center p-6 bg-black/10 backdrop-blur-[2px] animate-fade-in">
          <div className="bg-white rounded-[24px] p-6 w-full max-w-[300px] shadow-xl border border-gray-100 flex flex-col items-center text-center animate-slide-up">
            <h3 className="text-[14px] font-black text-gray-900 leading-tight mb-2">
              {confirmModal.title}
            </h3>
            <p className="text-[11px] font-medium text-gray-500 leading-normal mb-6">
              {confirmModal.text}
            </p>
            <div className="flex gap-2 w-full">
              <button
                onClick={() => setConfirmModal(null)}
                className="flex-1 py-3 bg-gray-50 text-gray-400 font-bold text-[10px] uppercase tracking-widest rounded-xl active:bg-gray-100 transition-all">
                VAZGEÇ
              </button>
              <button
                onClick={confirmModal.onConfirm}
                className="flex-1 py-3 bg-gray-900 text-white font-bold text-[10px] uppercase tracking-widest rounded-xl shadow-lg active:scale-95 transition-all">
                ONAYLA
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Sade ve Minimalist Toast Bildirimi */}
      {modalNotice && (
        <div className="fixed inset-x-6 top-6 z-[120] animate-slide-down pointer-events-none">
          <div className={`pointer-events-auto bg-gray-900/95 backdrop-blur-md text-white rounded-2xl p-4 shadow-2xl flex items-center gap-4 border border-white/10
                          ${modalNotice.type === 'error' ? 'border-l-4 border-l-red-500' : 'border-l-4 border-l-emerald-500'}`}>
            <div className="text-xl shrink-0">{modalNotice.icon}</div>
            <div className="flex-1 min-w-0">
              <h4 className="text-[11px] font-black uppercase tracking-widest mb-0.5">{modalNotice.title}</h4>
              <p className="text-[10px] text-gray-300 font-medium leading-tight truncate">{modalNotice.text}</p>
            </div>
            <button onClick={() => setModalNotice(null)} className="p-2 hover:bg-white/10 rounded-lg transition-colors">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" /></svg>
            </button>
          </div>
        </div>
      )}
      {/* Üst Bilgi Çubuğu (Profesyonel & Premium) */}
      <div className="sticky top-0 h-[72px] bg-white/90 backdrop-blur-2xl border-b border-gray-100 z-50 flex items-center px-5 gap-3 shadow-sm shadow-gray-200/20">
        <button 
          onClick={() => navigate(-1)} 
          className="w-9 h-9 flex items-center justify-center rounded-xl bg-gray-50 text-gray-400 hover:text-gray-900 active:scale-95 transition-all"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 19l-7-7 7-7" /></svg>
        </button>
        
        <div 
          className="flex items-center gap-3 flex-1 min-w-0 cursor-pointer active:opacity-70 transition-opacity"
          onClick={() => navigate(`/user-profile/${isSeller ? roomData?.buyer_id : roomData?.seller_id}`)}
        >
          <div className="relative group shrink-0">
            <div className="w-10 h-10 rounded-full border-2 border-white bg-gray-50 overflow-hidden shadow-sm group-hover:shadow-md transition-all">
               <img src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${isSeller ? roomData?.buyer_id : roomData?.seller_id}`} alt="avatar" />
            </div>
            {/* Online Durum Rozeti */}
            <div className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-emerald-500 border-2 border-white rounded-full shadow-sm"></div>
          </div>
          
          <div className="flex flex-col min-w-0">
            <h2 className="text-[15px] font-black text-gray-900 leading-tight truncate tracking-tight">
              {isSeller ? roomData?.buyer_name : roomData?.seller_name}
            </h2>
            <div className="flex items-center gap-1.5 opacity-60">
               <span className="text-[9px] font-black text-indigo-600 uppercase tracking-[0.15em] truncate">
                 {roomData?.gig_title || 'CampusGig Hizmeti'}
               </span>
            </div>
          </div>
        </div>

        <button className="w-9 h-9 rounded-xl bg-gray-50 text-gray-400 flex items-center justify-center hover:text-gray-900 transition-all active:scale-95">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 12h.01M12 12h.01M19 12h.01M6 12a1 1 0 11-2 0 1 1 0 012 0zm7 0a1 1 0 11-2 0 1 1 0 012 0zm7 0a1 1 0 11-2 0 1 1 0 012 0z" /></svg>
        </button>
      </div>

      {((roomData?.status === 'escrow_locked' || 
        roomData?.session_status === 'awaiting_pin' || 
        roomData?.session_status === 'active' || 
        roomData?.status === 'awaiting_verification' || 
        roomData?.status === 'disputed') && roomData?.status !== 'completed') && (
        <div className="bg-white/70 backdrop-blur-xl border-b border-gray-100 p-4 z-20 animate-slide-down">

        {/* Durum 1: Ödeme Kilitli, Henüz Başlamadı */}
        {roomData?.status === 'escrow_locked' && !roomData.session_status && (
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between px-1">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 bg-blue-50 rounded-xl flex items-center justify-center text-blue-600">
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" /></svg>
                </div>
                <div className="flex flex-col">
                  <span className="text-[10px] font-black text-blue-600 uppercase tracking-[0.1em]">GÜVENLİ ÖDEME AKTİF</span>
                  <span className="text-[12px] font-bold text-gray-800 tabular-nums">İşlem koruma altında.</span>
                </div>
              </div>
            </div>
            {isSeller ? (
              <div className="flex gap-2">
                <button onClick={handleInitiateSession} className="flex-1 py-3.5 bg-gray-900 text-white rounded-[18px] text-[10px] font-black uppercase tracking-widest shadow-lg shadow-gray-900/10 active:scale-95 transition-all">
                  Oturumu Başlat
                </button>
                <button onClick={() => { const n = prompt("Dosya/Not linkini girin:"); if (n) handleSubmitWork('file', n) }} className="flex-1 py-3.5 bg-white text-gray-500 border border-gray-100 rounded-[18px] text-[10px] font-black uppercase tracking-widest active:scale-95 transition-all">
                  Hizmet Teslim Et
                </button>
              </div>
            ) : (
              <div className="bg-blue-50/50 p-4 rounded-2xl border border-blue-100/50 flex items-start gap-3">
                <div className="w-5 h-5 mt-0.5 text-blue-500">
                  <svg fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" /></svg>
                </div>
                <p className="text-[11px] text-blue-800 font-semibold leading-relaxed">Ödemeniz havuzda donduruldu. Satıcı işi başlattığında buradan kod paylaşımı yapabileceksiniz.</p>
              </div>
            )}
          </div>
        )}

        {/* Durum 2: PIN Bekleniyor */}
        {roomData?.session_status === 'awaiting_pin' && (
          <div className="flex flex-col gap-4 p-1">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 bg-amber-50 rounded-xl flex items-center justify-center text-amber-600">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" /></svg>
              </div>
              <div className="flex flex-col">
                <span className="text-[10px] font-black text-amber-600 uppercase tracking-widest">DOĞRULAMA GEREKİYOR</span>
                <span className="text-[12px] font-bold text-gray-800">Güvenli el sıkışma işlemi.</span>
              </div>
            </div>

            {!isSeller ? (
              <div className="bg-white border-2 border-amber-100 p-6 rounded-[28px] shadow-sm text-center relative overflow-hidden group">
                <div className="absolute top-0 left-0 w-full h-1 bg-amber-400"></div>
                <span className="text-[10px] font-black text-gray-400 uppercase tracking-[0.2em] block mb-2">GÜVENLİK KODUNUZ</span>
                <span className="text-4xl font-black text-gray-900 tracking-[0.25em]">{roomData?.session_pin}</span>
                <p className="mt-3 text-[10px] text-amber-600 font-bold uppercase tracking-tighter">BU KODU SADECE SATICIYA SÖYLEYİN</p>
              </div>
            ) : (
              <div className="flex flex-col gap-4">
                <div className="group relative">
                  <input
                    type="text"
                    placeholder="PIN"
                    value={pinInput}
                    onChange={(e) => setPinInput(e.target.value.replace(/\D/g, '').slice(0, 4))}
                    className="w-full bg-gray-50 border border-gray-200 rounded-2xl py-4 pt-7 text-center text-2xl font-black text-gray-900 tracking-[0.5em] focus:outline-none focus:border-amber-400 focus:bg-white transition-all shadow-inner"
                  />
                  <label className="absolute top-3 left-0 right-0 text-[9px] font-black text-gray-400 uppercase tracking-widest text-center">4 HANELİ KODU GİRİN</label>
                </div>

                <div className="relative">
                  <input
                    type="url"
                    placeholder="Ders Linki (Google Meet, Zoom vb.)"
                    value={customLink}
                    onChange={(e) => setCustomLink(e.target.value)}
                    className="w-full bg-gray-50 border border-gray-100 rounded-xl py-3 px-4 text-[12px] font-bold text-gray-600 focus:outline-none focus:border-blue-400 focus:bg-white transition-all"
                  />
                </div>

                <button onClick={handleVerifyPin} disabled={pinInput.length !== 4} className="w-full py-4 bg-gray-900 text-white rounded-2xl text-[11px] font-black uppercase tracking-[0.2em] shadow-xl shadow-gray-900/20 disabled:opacity-30 active:scale-95 transition-all">DOĞRULA VE BAŞLAT</button>
              </div>
            )}
          </div>
        )}

        {/* Durum 3: Ders/Görüşme Devam Ediyor */}
        {roomData?.session_status === 'in_progress' && (
          <div className="flex flex-col gap-4 animate-fade-in px-1">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="relative">
                  <div className="w-10 h-10 bg-emerald-50 rounded-xl flex items-center justify-center text-emerald-600">
                    <svg className="w-6 h-6 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                  </div>
                </div>
                <div className="flex flex-col">
                  <span className="text-[10px] font-black text-emerald-600 uppercase tracking-widest">OTURUM CANLI</span>
                  <span className="text-[14px] font-black text-gray-900 tabular-nums tracking-tight">
                    {Math.floor(sessionTimer / 60).toString().padStart(2, '0')}:{ (sessionTimer % 60).toString().padStart(2, '0')}
                  </span>
                </div>
              </div>
              {isSeller && (
                <button onClick={() => handleSubmitWork('lesson')} className="py-2.5 px-6 bg-red-600 text-white rounded-xl text-[10px] font-black uppercase tracking-widest shadow-lg shadow-red-500/20 active:scale-95 transition-all">
                  Oturumu Kapat
                </button>
              )}
            </div>

            <a href={roomData?.session_meeting_link} target="_blank" rel="noopener noreferrer"
              className="bg-indigo-600 p-4 rounded-[22px] flex items-center justify-between group active:scale-[0.98] transition-all shadow-xl shadow-indigo-500/20 border border-indigo-400/20">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-white/10 rounded-xl flex items-center justify-center text-white backdrop-blur-md">
                   <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                </div>
                <div className="flex flex-col">
                  <span className="text-[10px] font-black text-indigo-200 uppercase tracking-widest">Ders Odası</span>
                  <span className="text-[13px] font-black text-white tracking-tight italic">Katılmak için tıklayın</span>
                </div>
              </div>
              <div className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-white group-hover:bg-white group-hover:text-indigo-600 transition-all">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M9 5l7 7-7 7" /></svg>
              </div>
            </a>
          </div>
        )}

        {/* Durum 4: Onay Bekleniyor / İtiraz */}
        {roomData?.status === 'awaiting_verification' && (
          <div className="flex flex-col gap-4 px-1">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 bg-orange-50 rounded-xl flex items-center justify-center text-orange-600">
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                </div>
                <div className="flex flex-col">
                  <span className="text-[10px] font-black text-orange-600 uppercase tracking-widest">TESLİMAT TAMAMLANDI</span>
                  <span className="text-[12px] font-bold text-gray-800 tracking-tight">Onay bekliyor.</span>
                </div>
              </div>
            </div>

            <div className="bg-white border border-gray-100 rounded-[28px] p-5 shadow-sm ring-1 ring-gray-50">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">ÖZET</span>
              </div>
              {roomData.work_proof?.type === 'lesson' ? (
                <div className="flex flex-col gap-2">
                  <div className="flex justify-between items-center">
                    <span className="text-[12px] font-bold text-gray-500">Oturum Süresi</span>
                    <span className="text-[12px] font-black text-gray-900 tabular-nums">{Math.floor(roomData.work_proof.duration / 60)}:{(roomData.work_proof.duration % 60).toString().padStart(2, '0')}</span>
                  </div>
                  <p className="text-[11px] text-gray-400 font-semibold italic mt-1 leading-relaxed">Güvenli el sıkışma sağlandı, oturum başarıyla kaydedildi.</p>
                </div>
              ) : (
                <div className="flex flex-col gap-2">
                  <div className="flex justify-between items-center">
                    <span className="text-[12px] font-bold text-gray-500">Teslim Edilen</span>
                    <span className="text-[12px] font-black text-indigo-600 underline underline-offset-4 decoration-2 truncate max-w-[160px]">{roomData.work_proof?.note}</span>
                  </div>
                </div>
              )}
            </div>

            {!isSeller ? (
              <div className="flex gap-2.5">
                <button onClick={handleApproveJob} className="flex-1 py-4 bg-gray-900 text-white rounded-[20px] text-[11px] font-black uppercase tracking-widest shadow-xl shadow-gray-900/10 active:scale-95 transition-all">ÖDEMEYİ SERBEST BIRAK</button>
                <button onClick={handleDispute} className="px-6 py-4 bg-white text-red-600 border border-red-100 rounded-[20px] text-[11px] font-black uppercase tracking-widest active:bg-red-50 transition-all">İTİRAZ</button>
              </div>
            ) : (
              <div className="flex flex-col gap-2">
                <button onClick={handleApproveJob} className="w-full py-4 bg-gray-50 text-gray-400 rounded-2xl text-[10px] font-black uppercase tracking-widest border border-gray-100 flex items-center justify-center gap-3">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                  48 SAAT SONRA OTOMATİK ONAY
                </button>
              </div>
            )}
          </div>
        )}

        {roomData?.status === 'disputed' && (
          <div className="bg-red-900 p-5 rounded-[28px] animate-fade-in flex flex-col gap-1.5 shadow-xl shadow-red-900/10">
            <div className="flex items-center gap-2 text-white/60">
               <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
               <span className="text-[10px] font-black uppercase tracking-[0.2em]">İTİRAZ AŞAMASI</span>
            </div>
            <span className="text-[13px] font-bold text-white leading-relaxed">Bu işlem moderasyon ekibimiz tarafından incelenmektedir. Tüm bakiyeler dondurulmuştur.</span>
          </div>
        )}
      </div>
    )}

      {/* Mesaj Alanı */}
      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-4 no-scrollbar">
        {messages.map((msg) => (
          <div key={msg.id} className={`flex flex-col ${msg.sender_id === currentUser.uid ? 'items-end' : 'items-start'}`}>
            {msg.type === 'offer' ? (
              <div className="w-full max-w-[300px] animate-fade-in my-2">
                <div className="bg-white rounded-[28px] border border-gray-100 shadow-xl shadow-gray-200/40 overflow-hidden">
                  <div className="bg-indigo-600 px-5 py-4 flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 bg-white/20 backdrop-blur-md rounded-xl flex items-center justify-center">
                        <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>
                      </div>
                      <span className="text-[12px] font-black text-white uppercase tracking-widest text-shadow-sm">Sözleşme Teklifi</span>
                    </div>
                  </div>
                  
                  <div className="p-5 flex flex-col gap-4">
                    <div className="flex flex-col gap-1.5">
                      <p className="text-[13px] font-bold text-gray-800 leading-relaxed italic">
                        "{msg.content}"
                      </p>
                      <div className="flex items-center gap-2">
                        <div className={`px-2 py-0.5 rounded-md text-[9px] font-black uppercase tracking-widest
                          ${msg.status === 'accepted' ? 'bg-emerald-50 text-emerald-600' : msg.status === 'rejected' ? 'bg-red-50 text-red-600' : 'bg-indigo-50 text-indigo-600'}`}>
                          {msg.status === 'accepted' ? 'SÖZLEŞME AKTİF' : msg.status === 'rejected' ? 'TEKLİF İPTAL EDİLDİ' : 'ONAYINIZ BEKLENİYOR'}
                        </div>
                      </div>
                    </div>

                    <div className="bg-gray-50 rounded-xl px-3 py-2 border border-gray-100 flex items-center justify-between">
                      <span className="text-[10px] font-bold text-gray-400 uppercase">Geçerlilik Süresi</span>
                      <span className="text-[10px] font-black text-gray-700 tracking-wider">60 DAKİKA</span>
                    </div>

                    {msg.status === 'accepted' ? (
                      <div className="flex flex-col items-center py-2">
                        <div className="w-full h-px bg-gray-100 mb-4"></div>
                        <div className="flex items-center gap-2 text-emerald-600">
                          <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" /></svg>
                          <span className="text-[11px] font-black uppercase tracking-[0.15em]">ÖDEME KİLİTLENDİ</span>
                        </div>
                      </div>
                    ) : msg.status === 'rejected' ? (
                      <div className="flex flex-col items-center py-2">
                        <div className="w-full h-px bg-gray-100 mb-4"></div>
                        <div className="flex items-center gap-2 text-red-400">
                          <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" /></svg>
                          <span className="text-[11px] font-black uppercase tracking-[0.15em]">TALEP REDDEDİLDİ</span>
                        </div>
                      </div>
                    ) : msg.sender_id !== currentUser.uid ? (
                      <div className="flex gap-2.5 mt-2">
                        <button onClick={() => handleOfferResponse('NO', msg.id)} className="flex-1 py-3.5 rounded-[18px] bg-white text-gray-500 font-black text-[10px] hover:bg-gray-50 transition-all uppercase tracking-widest border border-gray-200 active:scale-95">REDDET</button>
                        <button onClick={() => handleOfferResponse('YES', msg.id)} disabled={loading}
                          className={`flex-1 py-3.5 rounded-[18px] text-white font-black text-[10px] shadow-lg shadow-indigo-600/20 active:scale-95 transition-all uppercase tracking-widest bg-indigo-600`}>
                          ONAYLA
                        </button>
                      </div>
                    ) : (
                      msg.status === 'pending' && (
                        <div className="text-center py-2 border-t border-gray-50 mt-2">
                          <span className="text-[9px] font-black text-gray-300 uppercase tracking-widest italic animate-pulse">ALICININ YANITI BEKLENİYOR...</span>
                        </div>
                      )
                    )}
                  </div>
                </div>
              </div>
            ) : msg.type === 'system_info' ? (
              <div className="w-full flex justify-center my-6 animate-fade-in">
                <div className={`relative px-6 py-4 rounded-[24px] border border-gray-100 shadow-sm max-w-[85%]
                                 ${msg.subtype === 'delivery' ? 'bg-amber-50/50' :
                    msg.subtype === 'approval' ? 'bg-emerald-50/50' :
                      msg.subtype === 'dispute' ? 'bg-red-50/50' :
                        'bg-gray-50'}`}>
                  
                  <div className="flex items-center gap-3 mb-2">
                    <div className={`w-6 h-6 rounded-lg flex items-center justify-center shadow-sm
                                       ${msg.subtype === 'delivery' ? 'bg-amber-400 text-white' :
                        msg.subtype === 'approval' ? 'bg-emerald-500 text-white' :
                          msg.subtype === 'dispute' ? 'bg-red-500 text-white' :
                            'bg-gray-400 text-white'}`}>
                       <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         {msg.subtype === 'delivery' ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" /> :
                          msg.subtype === 'approval' ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /> :
                          msg.subtype === 'dispute' ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /> :
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />}
                       </svg>
                    </div>
                    <span className={`text-[10px] font-black uppercase tracking-[0.15em]
                                       ${msg.subtype === 'delivery' ? 'text-amber-700' :
                        msg.subtype === 'approval' ? 'text-emerald-700' :
                          msg.subtype === 'dispute' ? 'text-red-700' :
                            'text-gray-700'}`}>
                      {msg.subtype === 'delivery' ? 'RESMİ TESLİMAT KAYDI' :
                        msg.subtype === 'approval' ? 'İŞLEM TAMAMLANDI' :
                          msg.subtype === 'dispute' ? 'RESMİ İTİRAZ AŞAMASI' : 'SİSTEM BİLDİRİMİ'}
                    </span>
                  </div>

                  <p className={`text-[12px] font-bold leading-relaxed mb-3
                                  ${msg.subtype === 'delivery' ? 'text-amber-900' :
                      msg.subtype === 'approval' ? 'text-emerald-900' :
                        msg.subtype === 'dispute' ? 'text-red-900' :
                          'text-gray-900'}`}>
                    {msg.subtype === 'delivery' 
                      ? (isSeller ? 'İş kanıtını sundunuz. Alıcı onayı için 48 saatlik süreç başladı.' : 'Satıcı işi teslim etti! Lütfen detayları inceleyip onay verin.')
                      : msg.subtype === 'approval'
                        ? (isSeller ? 'Bakiye hesabınıza aktarıldı. Başarıyla tamamlanan bir işlem daha!' : 'Ödeme onaylandı. Hizmet bedeli satıcı hesabına aktarıldı.')
                        : (msg.content.split(': ')[1] || msg.content)
                    }
                  </p>

                  {(msg.subtype === 'delivery' && msg.meeting_link) && (
                    <a 
                      href={msg.meeting_link} 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 px-4 py-2 bg-amber-200/50 hover:bg-amber-300 text-amber-900 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all shadow-sm"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                      TESLİMAT AYRINTILARI / KAYIT
                    </a>
                  )}


                  <div className="absolute -bottom-2.5 right-6 px-2 py-0.5 bg-white border border-gray-100 rounded-md shadow-sm">
                    <span className="text-[8px] font-black text-gray-400 uppercase tracking-widest tabular-nums">{msg.created_at?.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                  </div>
                </div>
              </div>
            ) : (
              <div className={`max-w-[75%] flex flex-col ${msg.sender_id === currentUser.uid ? 'items-end' : 'items-start'}`}>
                <div className={`p-4 rounded-[20px] text-[13px] font-medium leading-relaxed shadow-sm transition-all
                                  ${msg.sender_id === currentUser.uid
                    ? (roomData?.gig_type === 'marketplace'
                      ? 'bg-emerald-600 text-white rounded-tr-none'
                      : 'bg-indigo-600 text-white rounded-tr-none')
                    : 'bg-white text-gray-800 border border-gray-100 rounded-tl-none'}`}>
                  {msg.content}
                </div>
                <div className="flex items-center gap-1.5 mt-1.5 px-1">
                   {msg.sender_id === currentUser.uid && <span className="text-[8px] font-black text-gray-300 uppercase tracking-widest">GÖNDERİLDİ</span>}
                   <span className="text-[9px] font-bold text-gray-400">
                     {msg.created_at?.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                   </span>
                </div>
              </div>
            )}
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Alt Giriş Alanı */}
      <div className="bg-white p-5 border-t border-gray-100 z-20 transition-all">
        {roomData?.status === 'completed' ? (
          <div className="flex flex-col gap-4">
            {(!roomData.review_submitted && !isSeller && !reviewSent) ? (
              <div className="bg-indigo-50/50 p-6 rounded-[32px] border border-dashed border-indigo-200 animate-fade-in">
                <div className="flex flex-col items-center text-center">
                  <div className="text-2xl mb-2">⭐</div>
                  <h4 className="text-[14px] font-black text-indigo-900 uppercase tracking-widest mb-1">Deneyimini Puanla</h4>
                  <p className="text-[11px] text-indigo-400 font-medium mb-4">Satıcının hizmet kalitesini değerlendir.</p>
                  
                  {/* Yıldızlar */}
                  <div className="flex gap-2 mb-4">
                    {[1, 2, 3, 4, 5].map((star) => (
                      <button 
                        key={star} 
                        onClick={() => setRating(star)}
                        className={`text-2xl transition-all ${rating >= star ? 'scale-125' : 'opacity-30 grayscale'}`}>
                        ⭐
                      </button>
                    ))}
                  </div>

                  <textarea 
                    value={reviewText}
                    onChange={(e) => setReviewText(e.target.value)}
                    placeholder="Bu hizmet hakkında ne düşünüyorsun? (Opsiyonel)"
                    className="w-full bg-white/60 border border-indigo-100 rounded-2xl p-3 text-[12px] font-medium text-gray-700 focus:outline-none focus:border-indigo-300 min-h-[80px] mb-4"
                  />

                  <button 
                    onClick={handleSendReview}
                    disabled={loading || rating === 0}
                    className="w-full py-3.5 bg-indigo-600 text-white rounded-2xl text-[11px] font-black uppercase tracking-[0.1em] shadow-xl shadow-indigo-600/20 active:scale-95 transition-all disabled:opacity-50">
                    Değerlendirmeyi Gönder
                  </button>
                </div>
              </div>
            ) : (
              <div className="text-center py-6 bg-blue-50/50 rounded-[32px] border border-dashed border-blue-200">
                <p className="text-[11px] font-black text-blue-500 uppercase tracking-widest mb-1">Görüşme Tamamlandı</p>
                <p className="text-[10px] text-blue-400 font-medium italic">Sistem kayıt altına alındı. Teşekkür ederiz.</p>
              </div>
            )}
          </div>
        ) : myMessageCount < 5 ? (
          <div className="flex flex-col gap-3">
            {isSeller && roomData?.status === 'chatting' && (
              <button
                onClick={() => {
                  setConfirmModal({
                    title: "Resmi Teklif Gönderilsin mi?",
                    text: "Bu işlem ile karşı tarafa ödeme talebi iletilecektir. Onaylıyor musunuz?",
                    onConfirm: () => {
                      sendMessage(null, 'offer');
                      setConfirmModal(null);
                    }
                  });
                }}
                className="w-full py-2.5 bg-purple-50 text-purple-600 rounded-xl text-[11px] font-black uppercase tracking-widest border border-purple-100 hover:bg-purple-100 transition-all mb-1">
                Resmi Teklif Gönder (+0 Mesaj)
              </button>
            )}
            <form onSubmit={(e) => sendMessage(e, 'text')} className="flex items-center bg-gray-50 rounded-[24px] px-2 py-1.5 border border-gray-100 focus-within:border-gray-200 transition-all shadow-inner">
              <input
                type="text"
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                maxLength={140}
                placeholder="Mesajınızı yazın..."
                className="flex-1 bg-transparent px-3 py-2.5 focus:outline-none text-[13px] font-bold text-gray-700 placeholder:text-gray-300"
              />
              <button type="submit"
                className={`p-3 ml-2 text-white rounded-2xl active:scale-90 transition-all shadow-lg
                                 ${roomData?.gig_type === 'marketplace' ? 'bg-[#10B981] shadow-emerald-500/20' : 'bg-[#4F46E5] shadow-indigo-500/20'}`}>
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" /></svg>
              </button>
            </form>
            <div className="flex justify-between items-center px-1">
              <div className="flex flex-col">
                <span className="text-[9px] font-bold text-gray-400 uppercase tracking-widest">Mesaj Hakkı: {5 - myMessageCount}/5</span>
                <span className="text-[7px] font-black text-amber-500 uppercase tracking-tighter">Mesajlar 12 saatte bir güncellenir.</span>
              </div>
              <span className={`text-[9px] font-bold uppercase tracking-widest ${newMessage.length > 120 ? 'text-red-400' : 'text-gray-400'}`}>{newMessage.length}/140</span>
            </div>
          </div>
        ) : (
          <div className="text-center py-4 bg-gray-50 rounded-2xl border border-dashed border-gray-200">
            <p className="text-[11px] font-black text-gray-400 uppercase tracking-widest">Bu görüşme için limitiniz dolmuştur.</p>
          </div>
        )}
      </div>
    </div>
  );
}
