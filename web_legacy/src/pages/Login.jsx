import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

export default function Login() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ email: '', password: '' });

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleSubmit = (e) => {
    e.preventDefault();
    navigate('/');
  };

  return (
    <div className="flex flex-col h-full bg-[#FAFAFC] relative overflow-hidden">

      {/* Animated Glowing Mesh Backgrounds */}
      <div className="absolute top-[-10%] left-[-20%] w-[80%] h-[50%] bg-[#3B82F6]/20 rounded-full mix-blend-multiply filter blur-[80px] animate-blob z-0"></div>
      <div className="absolute top-[20%] right-[-10%] w-[70%] h-[60%] bg-[#8B5CF6]/20 rounded-full mix-blend-multiply filter blur-[80px] animate-blob z-0" style={{ animationDelay: '2s' }}></div>
      <div className="absolute bottom-[-20%] left-[10%] w-[60%] h-[50%] bg-[#6366f1]/20 rounded-full mix-blend-multiply filter blur-[80px] animate-blob z-0" style={{ animationDelay: '4s' }}></div>

      <div className="flex-1 flex flex-col justify-center px-8 z-10 relative">

        <div className="mb-14">
          <div className="w-14 h-14 bg-white/70 backdrop-blur-md rounded-2xl shadow-sm border border-white/50 flex items-center justify-center mb-6">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-7 w-7 text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
          </div>
          <h1 className="text-4xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-purple-600 tracking-tight mb-2">
            Tekrar<br />Hoş Geldin.
          </h1>
          <p className="text-gray-500 mt-2 font-medium text-sm leading-relaxed">
            Kampüs ağında yerini al,<br />kendi ekosisteminde bilgini değere dönüştür.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-6">

          {/* Animated Input Field - Email */}
          <div className="relative group mt-2">
            <input type="email" name="email" id="email" value={formData.email} onChange={handleChange} required placeholder=" "
              className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px]" />
            <label htmlFor="email" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none 
                              peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                              peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
              Öğrenci Email
            </label>
            {/* Sliding Bottom Border */}
            <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
          </div>

          {/* Animated Input Field - Password */}
          <div className="relative group mt-4">
            <input type="password" name="password" id="password" value={formData.password} onChange={handleChange} required placeholder=" "
              className="w-full bg-transparent border-b border-gray-300 pb-2 pt-5 focus:outline-none focus:border-transparent peer text-[#111827] font-semibold text-[15px] tracking-widest" />
            <label htmlFor="password" className={`absolute left-0 top-5 text-gray-400 font-medium text-[14px] transition-all duration-300 pointer-events-none tracking-normal
                              peer-focus:-top-2 peer-focus:text-[11px] peer-focus:text-purple-600 peer-focus:font-bold peer-focus:tracking-wider peer-focus:uppercase
                              peer-valid:-top-2 peer-valid:text-[11px] peer-valid:text-purple-600 peer-valid:font-bold peer-valid:tracking-wider peer-valid:uppercase`}>
              Şifren
            </label>
            <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0 h-[2px] bg-gradient-to-r from-blue-500 to-purple-500 peer-focus:w-full transition-all duration-500 ease-out"></div>
          </div>

          <div className="flex justify-end relative z-20 mt-1">
            <span className="text-xs font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-purple-600 cursor-pointer active:opacity-70 transition-opacity tracking-wide">
              ŞİFREMİ UNUTTUM
            </span>
          </div>

          <button type="submit"
            className="mt-4 w-full bg-[#111827] hover:bg-gradient-to-r hover:from-blue-600 hover:to-purple-600 text-white font-bold text-[16px] py-4 rounded-2xl shadow-xl shadow-gray-900/10 active:scale-[0.98] transition-all duration-300 flex justify-center items-center gap-2 group relative overflow-hidden">
            <div className="absolute inset-0 bg-white/20 translate-x-[100%] group-active:translate-x-0 transition-transform duration-300 ease-out"></div>
            <span>Giriş Yap</span>
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 group-hover:translate-x-1 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </button>
        </form>

        <div className="mt-12 text-center flex flex-col items-center gap-4 relative z-20">
          <span className="text-xs font-semibold text-gray-400 uppercase tracking-widest">CampusGig'de Yeni misin?</span>
          <Link to="/register" className="inline-flex justify-center items-center w-full bg-white/60 backdrop-blur-lg border border-white/50 text-[#111827] py-4 rounded-2xl font-extrabold text-sm shadow-[0_8px_30px_rgba(0,0,0,0.04)] active:scale-[0.98] transition-all duration-300">
            ÜCRETSİZ ÖĞRENCİ HESABI AÇ
          </Link>
        </div>
      </div>

    </div>
  );
}
