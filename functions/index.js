const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const defaultFirestore = admin.firestore();

// --- 1. İŞLEM BAŞLATMA (ESCROW'A ALMA) ---
exports.initiateTransaction = functions.https.onCall(async (data, context) => {
  // 1. Kimlik Kontrolü
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "İşlem yapabilmek için giriş yapmalısınız.");
  }

  const { gigId, sellerId, amount, type, priceType, roomId } = data;
  const buyerId = context.auth.uid;
  
  // Girdi Normalizasyonu
  const safeAmount = Number(amount);

  // 2. Temel Validasyonlar
  if (buyerId === sellerId) {
    throw new functions.https.HttpsError("invalid-argument", "Kendi ilanınızı satın alamazsınız.");
  }

  if (isNaN(safeAmount) || (safeAmount <= 0 && priceType !== 'swap')) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz işlem tutarı.");
  }

  try {
    const result = await defaultFirestore.runTransaction(async (t) => {
      // 3. Kullanıcı Verisi Çekme
      const buyerRef = defaultFirestore.collection("users").doc(buyerId);
      const buyerDoc = await t.get(buyerRef);
      
      if (!buyerDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Kullanıcı profiliniz bulunamadı. Lütfen kayıt olduğunuzdan emin olun.");
      }

      const buyerData = buyerDoc.data();
      const balanceField = priceType === 'swap' ? 'wallet_time_credit' : 'wallet_cgt';
      const currentBalance = Number(buyerData[balanceField] || 0);

      // 4. Bakiye Kontrolü
      if (currentBalance < safeAmount) {
        throw new functions.https.HttpsError("failed-precondition", `Yetersiz bakiye! Gereken: ${safeAmount}, Mevcut: ${currentBalance}`);
      }

      // 5. Veritabanı Operasyonları
      // A. Bakiyeden Düş
      t.update(buyerRef, { [balanceField]: admin.firestore.FieldValue.increment(-safeAmount) });

      // B. Escrow Kaydı Oluştur
      const transactionRef = defaultFirestore.collection("transactions").doc();
      const transactionId = transactionRef.id;

      t.set(transactionRef, {
        gig_id: gigId,
        buyer_id: buyerId,
        seller_id: sellerId,
        amount: safeAmount,
        price_type: priceType,
        status: "escrow",
        created_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // C. Sohbet Odasını Güncelle
      if (roomId) {
        const roomRef = defaultFirestore.collection("chat_rooms").doc(roomId);
        t.update(roomRef, { 
          active_transaction_id: transactionId,
          status: 'escrow_locked' 
        });
      }

      // D. İlan Durumunu Güncelle (Bounty ise)
      if (type === 'bounties') {
        t.update(defaultFirestore.collection("bounties").doc(gigId), { 
          status: "in_progress", 
          worker_id: buyerId 
        });
      }

      return { transactionId };
    });

    return { success: true, ...result };
  } catch (error) {
    console.error("TRANS_ERROR:", error);
    // Eğer zaten bir HttpsError ise direkt fırlat
    if (error instanceof functions.https.HttpsError) throw error;
    // Beklenmedik bir hata ise maskeleme yapmadan mesajı ilet
    throw new functions.https.HttpsError("internal", error.message || "İşlem sırasında bilinmeyen bir hata oluştu.");
  }
});

// --- 1.5 İŞİ TESLİM ETME (KANIT SUNMA) ---
exports.submitWork = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız.");
  
  const { roomId, transactionId, workProof } = data;
  const sellerId = context.auth.uid;

  try {
    const roomRef = defaultFirestore.collection("chat_rooms").doc(roomId);
    const transRef = defaultFirestore.collection("transactions").doc(transactionId);

    // Otomatik onay süresi: 48 saat sonra
    const autoApproveDate = new Date();
    autoApproveDate.setHours(autoApproveDate.getHours() + 48);

    await defaultFirestore.runTransaction(async (t) => {
      t.update(roomRef, {
        status: 'awaiting_verification',
        work_proof: workProof,
        submitted_at: admin.firestore.FieldValue.serverTimestamp()
      });

      t.update(transRef, {
        auto_approve_at: admin.firestore.Timestamp.fromDate(autoApproveDate),
        work_submitted: true
      });
    });

    return { success: true, autoApproveAt: autoApproveDate };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// --- 2. İŞLEMİ TAMAMLAMA (PARAYI SERBEST BIRAKMA) ---
exports.releaseEscrow = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız.");

  const { transactionId, roomId } = data;
  
  try {
    const result = await defaultFirestore.runTransaction(async (t) => {
      const transRef = defaultFirestore.collection("transactions").doc(transactionId);
      const transDoc = await t.get(transRef);
      if (!transDoc.exists) throw new Error("İşlem kaydı bulunamadı.");

      const transData = transDoc.data();
      if (transData.status === "completed") throw new Error("Bu işlem zaten tamamlanmış.");
      if (transData.status === "disputed") throw new Error("Bu işlem itiraz aşamasında, moderatör onayı gerekiyor.");

      // KONTROL: SADECE ALICI VEYA VADESİ DOLMUŞSA SATICI SERBEST BIRAKABİLİR
      const isBuyer = transData.buyer_id === context.auth.uid;
      const isSeller = transData.seller_id === context.auth.uid;
      const now = admin.firestore.Timestamp.now();
      const isAutoApproveExpired = transData.auto_approve_at && transData.auto_approve_at.toMillis() <= now.toMillis();

      if (!isBuyer && !(isSeller && isAutoApproveExpired)) {
         throw new Error("Ödemeyi serbest bırakma yetkiniz yok veya otomatik onay süresi henüz dolmadı.");
      }

      const sellerRef = defaultFirestore.collection("users").doc(transData.seller_id);
      const amount = transData.amount;
      
      let amountToSeller = amount;
      let systemFee = amount * 0.10;
      amountToSeller = amount - systemFee;

      // 1. Satıcının cüzdanına ekle
      const balanceField = transData.price_type === 'swap' ? 'wallet_time_credit' : 'wallet_cgt';
      t.update(sellerRef, { [balanceField]: admin.firestore.FieldValue.increment(amountToSeller) });

      // 2. İşlemi kapat
      t.update(transRef, { 
        status: "completed", 
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        fee_deducted: systemFee 
      });

      // 3. Sohbet odasını güncelle
      if (roomId) {
        t.update(defaultFirestore.collection("chat_rooms").doc(roomId), {
            status: 'completed',
            active_transaction_id: null
        });
      }

      // 4. Sistem hesabına komisyonu yaz
      const systemRef = defaultFirestore.collection("system").doc("wallet");
      t.set(systemRef, { 
        total_fees: admin.firestore.FieldValue.increment(systemFee) 
      }, { merge: true });

      return "İşlem tamamlandı, ödeme satıcıya aktarıldı.";
    });
    return { success: true, message: result };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// --- 3. İTİRAZ YÖNETİMİ (DISPUTE) ---
exports.disputeTransaction = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız.");
  
  const { transactionId, roomId, reason } = data;
  const callerId = context.auth.uid;

  try {
    const transRef = defaultFirestore.collection("transactions").doc(transactionId);
    const transDoc = await transRef.get();
    
    if (!transDoc.exists) throw new Error("İşlem bulunamadı.");
    const transData = transDoc.data();

    // Sadece satıcı veya alıcı itiraz edebilir
    if (transData.seller_id !== callerId && transData.buyer_id !== callerId) {
      throw new Error("Bu işleme itiraz etme yetkiniz yok.");
    }

    await transRef.update({
      status: 'disputed',
      dispute_reason: reason,
      disputed_by: callerId,
      disputed_at: admin.firestore.FieldValue.serverTimestamp()
    });

    if (roomId) {
      await defaultFirestore.collection("chat_rooms").doc(roomId).update({
        status: 'disputed'
      });
    }

    return { success: true, message: "İtiraz talebi moderatörlere iletildi." };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});
