import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { auth, db } from '../firebase';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';

export default function Register() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    email: '', password: '', firstName: '', lastName: '', university: '', department: '', grade: ''
  });

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });
  const handleNext = () => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    // 1. ADIM KONTROLLERİ (Email ve Şifre)
    if (step === 1) {
      const email = formData.email.trim();
      const password = formData.password.trim();

      if (!email.toLowerCase().includes('.edu.tr')) {
        alert('CampusGig sadece .edu.tr uzantılı üniversite e-postaları ile kullanılabilir.');
        return;
      }
      if (!emailRegex.test(email)) {
        alert('Lütfen geçerli bir e-posta adresi giriniz (Örn: isim@uni.edu.tr)');
        return;
      }
      if (password.length < 6) {
        alert('Güvenliğiniz için şifreniz en az 6 karakter olmalıdır.');
        return;
      }
    }

    // 2. ADIM KONTROLLERİ (Ad Soyad)
    if (step === 2) {
      if (!formData.firstName.trim() || !formData.lastName.trim()) {
        alert('Lütfen adınızı ve soyadınızı giriniz.');
        return;
      }
    }

    if (step < 3) setStep(step + 1);
  };
  const handleBack = () => { if (step > 1) setStep(step - 1); };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // SON KONTROL (Her ihtimale karşı)
    const email = formData.email.trim();
    const password = formData.password.trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!email.toLowerCase().includes('.edu.tr') || !emailRegex.test(email) || password.length < 6) {
      setStep(1); // Hatayı düzeltmesi için 1. adıma geri at
      alert('Lütfen e-posta ve şifrenizi kontrol ediniz.');
      return;
    }

    if (step < 3) return handleNext();

    setLoading(true);
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;

      await setDoc(doc(db, 'users', user.uid), {
        id: user.uid,
        firstName: formData.firstName.trim(),
        lastName: formData.lastName.trim(),
        email: email,
        university: formData.university,
        department: formData.department.trim(),
        grade: formData.grade,
        wallet_cgt: 150, // Hoşgeldin Hediyesi
        wallet_time_credit: 0,
        daily_time_credit_count: 0, // Günlük kota takibi
        last_time_credit_at: null,    // Son işlem zamanı
        isPremium: false,
        avatar_url: `https://api.dicebear.com/7.x/notionists/svg?seed=${user.uid}&backgroundColor=EADDFF`,
        created_at: serverTimestamp()
      });

      navigate('/');
    } catch (error) {
      console.error("Kayıt Hatası: ", error);
      let message = "Kayıt başarısız";
      if (error.code === 'auth/email-already-in-use') message = "Bu e-posta adresi zaten kullanımda.";
      if (error.code === 'auth/invalid-email') message = "Geçersiz e-posta formatı. Lütfen kontrol edin.";
      if (error.code === 'auth/weak-password') message = "Şifre çok zayıf (En az 6 karakter olmalı).";
      alert(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#FAFAFC] relative overflow-hidden">

      {/* Animated Glowing Mesh Backgrounds */}
      <div className="absolute top-[-10%] left-[-20%] w-[80%] h-[50%] bg-[#3B82F6]/20 rounded-full mix-blend-multiply filter blur-[80px] animate-blob z-0"></div>
      <div className="absolute top-[20%] right-[-10%] w-[70%] h-[60%] bg-[#8B5CF6]/20 rounded-full mix-blend-multiply filter blur-[80px] animate-blob z-0" style={{ animationDelay: '2s' }}></div>

      {/* Header & Geri Butonu */}
      <div className="pt-12 px-8 pb-4 flex justify-between items-center z-10 relative">
        {step > 1 ? (
          <button onClick={handleBack} className="p-3 bg-white/60 backdrop-blur-md rounded-2xl shadow-sm border border-white/50 active:scale-90 transition-all text-gray-800">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
            </svg>
          </button>
        ) : (
          <Link to="/login" className="p-3 bg-white/60 backdrop-blur-md rounded-2xl shadow-sm border border-white/50 active:scale-90 transition-all text-gray-800">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
            </svg>
          </Link>
        )}

        {/* Adım Göstergesi */}
        <div className="flex gap-2">
          <div className={`h-1.5 rounded-full transition-all duration-500 ease-out ${step >= 1 ? 'w-8 bg-gradient-to-r from-blue-500 to-purple-500' : 'w-2 bg-gray-200'}`}></div>
          <div className={`h-1.5 rounded-full transition-all duration-500 ease-out ${step >= 2 ? 'w-8 bg-gradient-to-r from-blue-500 to-purple-500' : 'w-2 bg-gray-200'}`}></div>
          <div className={`h-1.5 rounded-full transition-all duration-500 ease-out ${step >= 3 ? 'w-8 bg-gradient-to-r from-blue-500 to-purple-500' : 'w-2 bg-gray-200'}`}></div>
        </div>
      </div>

      {/* Form Alanı */}
      <div className="flex-1 px-8 pt-6 pb-8 flex flex-col z-10 overflow-y-auto no-scrollbar relative">
        <div className="mb-10">
          <h1 className="text-3xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-purple-600 tracking-tight mb-2">
            {step === 1 && "Okul Hesabın"}
            {step === 2 && "Profilini Çiz"}
            {step === 3 && "Eğitim Ağın"}
          </h1>
          <p className="text-gray-500 font-medium text-[13px] leading-relaxed">
            {step === 1 && "CampusGig deneyimi için sana özel edu.tr alan adınla başlayalım."}
            {step === 2 && "Diğer yeteneklerin ve öğrencilerin seni tanıyabilmesi için kimliğin."}
            {step === 3 && "Seni kampüs ekosisteminde doğru noktaya yerleştirelim."}
          </p>
        </div>

        <form className="flex-1 flex flex-col gap-6" onSubmit={handleSubmit}>

          {/* ADIM 1 */}
          {step === 1 && (
            <div className="space-y-6 animate-fade-in">
              <div className="relative group">
                <input type="email" name="email" id="email" value={formData.email} onChange={handleChange} required placeholder=" "
                  className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px]" />
                <label htmlFor="email" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none 
                                  peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                                  peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
                  öğrenci.mail@edu.tr
                </label>
                <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
                {formData.email && !formData.email.includes('.edu.tr') && (
                  <span className="absolute -bottom-5 right-0 text-[10px] text-red-500 font-bold tracking-widest uppercase">EDU.TR ZORUNLUDUR</span>
                )}
              </div>

              <div className="relative group mt-4">
                <input type="password" name="password" id="password" value={formData.password} onChange={handleChange} required placeholder=" "
                  className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px] tracking-widest" />
                <label htmlFor="password" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none tracking-normal
                                  peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                                  peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
                  Güvenli Şifre
                </label>
                <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
              </div>
            </div>
          )}

          {/* ADIM 2 */}
          {step === 2 && (
            <div className="space-y-6 animate-fade-in">
              <div className="flex flex-col items-center justify-center mb-4">
                <div className="w-20 h-20 bg-white/50 backdrop-blur-md rounded-2xl shadow-sm border border-gray-200 flex items-center justify-center text-gray-400 mb-2 relative overflow-hidden active:scale-95 transition-transform cursor-pointer">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <span className="text-[10px] uppercase font-bold tracking-widest text-[#8B5CF6]">Avatar Ekle</span>
              </div>

              <div className="relative group mt-2">
                <input type="text" name="firstName" id="firstName" value={formData.firstName} onChange={handleChange} required placeholder=" "
                  className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px]" />
                <label htmlFor="firstName" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none 
                                  peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                                  peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
                  Adın
                </label>
                <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
              </div>

              <div className="relative group mt-2">
                <input type="text" name="lastName" id="lastName" value={formData.lastName} onChange={handleChange} required placeholder=" "
                  className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px]" />
                <label htmlFor="lastName" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none 
                                  peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                                  peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
                  Soyadın
                </label>
                <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
              </div>
            </div>
          )}

          {/* ADIM 3 */}
          {step === 3 && (
            <div className="space-y-6 animate-fade-in">
              <div className="relative group">
                <select name="university" value={formData.university} onChange={handleChange} required
                  className={`w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer font-semibold text-[15px] appearance-none ${formData.university ? 'text-[#111827]' : 'text-gray-400'}`}>
                  <option value="" disabled hidden>Seçim yapınız</option>
                  <option value="boun" className="text-black">Boğaziçi Üniversitesi</option>
                  <option value="itu" className="text-black">İstanbul Teknik Üniversitesi</option>
                  <option value="metu" className="text-black">Orta Doğu Teknik Üniversitesi</option>
                </select>
                <label className={`absolute left-0 transition-all duration-300 pointer-events-none 
                                  ${formData.university ? '-top-1 text-[11px] text-purple-600 font-bold tracking-wider uppercase' : 'top-5 text-gray-400 font-medium text-[15px] peer-focus:-top-1 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase'}`}>
                  Üniversiten
                </label>
                <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
              </div>

              <div className="relative group mt-2">
                <input type="text" name="department" id="department" value={formData.department} onChange={handleChange} required placeholder=" "
                  className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px]" />
                <label htmlFor="department" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none 
                                  peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                                  peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
                  Bölümün
                </label>
                <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
              </div>

              <div className="mt-6">
                <label className="text-[11px] text-purple-600 font-bold tracking-wider uppercase mb-3 block">Sınıf Derecesi</label>
                <div className="flex flex-wrap gap-2">
                  {['Hazırlık', '1. Sınıf', '2. Sınıf', '3. Sınıf', '4. Sınıf', '5. Sınıf', '6. Sınıf', 'Lisansüstü'].map(g => (
                    <div key={g}
                      onClick={() => setFormData({ ...formData, grade: g })}
                      className={`px-4 py-2.5 rounded-xl text-xs font-extrabold cursor-pointer transition-all duration-300 border uppercase tracking-wider
                          ${formData.grade === g ? 'bg-[#111827] text-white border-transparent shadow-lg shadow-gray-900/20' : 'bg-transparent border-gray-200 text-gray-400 hover:border-purple-300'}`}>
                      {g}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          <div className="mt-auto pt-8">
            {step < 3 ? (
              <button type="button" onClick={handleNext}
                className="w-full bg-[#111827] hover:bg-gradient-to-r hover:from-blue-600 hover:to-purple-600 text-white font-bold text-lg py-4 rounded-2xl shadow-xl shadow-gray-900/10 active:scale-[0.98] transition-all duration-300 flex justify-center items-center gap-2">
                İleri
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M12.293 5.293a1 1 0 011.414 0l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-2.293-2.293a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            ) : (
              <button type="submit"
                className="w-full bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold text-lg py-4 rounded-2xl shadow-xl shadow-purple-500/30 active:scale-[0.98] transition-all duration-300 flex justify-center items-center">
                Katıl ve Keşfet
              </button>
            )}
          </div>

        </form>
      </div>
    </div>
  );
}
