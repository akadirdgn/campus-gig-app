import React from 'react';
import { X, Check, AlertCircle, Info, AlertTriangle } from 'lucide-react';

const icons = {
  success: {
    icon: <Check className="w-6 h-6 text-emerald-600" />,
    bg: 'bg-emerald-50',
    border: 'border-emerald-100',
    primaryBtn: 'bg-emerald-500 shadow-emerald-200'
  },
  error: {
    icon: <AlertCircle className="w-6 h-6 text-red-600" />,
    bg: 'bg-red-50',
    border: 'border-red-100',
    primaryBtn: 'bg-red-500 shadow-red-200'
  },
  warning: {
    icon: <AlertTriangle className="w-6 h-6 text-amber-600" />,
    bg: 'bg-amber-50',
    border: 'border-amber-100',
    primaryBtn: 'bg-amber-500 shadow-amber-200'
  },
  info: {
    icon: <Info className="w-6 h-6 text-indigo-600" />,
    bg: 'bg-indigo-50',
    border: 'border-indigo-100',
    primaryBtn: 'bg-indigo-500 shadow-indigo-200'
  }
};

export default function Modal({ 
  isOpen, 
  onClose, 
  onConfirm, 
  title, 
  message, 
  confirmText = 'Tamam', 
  cancelText = 'İptal',
  type = 'info',
  showCancel = true
}) {
  if (!isOpen) return null;

  const style = icons[type] || icons.info;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center px-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-[#111827]/40 backdrop-blur-sm animate-fade-in"
        onClick={onClose}
      ></div>

      {/* Modal Container */}
      <div className="bg-white w-full max-w-[340px] rounded-[32px] shadow-2xl relative z-10 overflow-hidden border border-white/20 animate-modal-in">
        
        {/* Header with Icon */}
        <div className="p-6 pb-2 flex flex-col items-center">
          <div className={`w-14 h-14 ${style.bg} ${style.border} border-2 rounded-2xl flex items-center justify-center mb-4 shadow-sm`}>
            {style.icon}
          </div>
          <h3 className="text-[18px] font-black text-[#111827] text-center px-2">
            {title}
          </h3>
        </div>

        {/* Content */}
        <div className="px-8 pb-8">
          <p className="text-[14px] text-gray-500 font-medium text-center leading-relaxed">
            {message}
          </p>
        </div>

        {/* Footer / Buttons */}
        <div className="px-6 pb-6 pt-2 flex flex-col gap-3">
          <button
            onClick={() => {
              onConfirm?.();
              onClose();
            }}
            className={`w-full py-4 rounded-2xl ${style.primaryBtn} text-white font-black text-[15px] shadow-lg active:scale-95 transition-all duration-200`}
          >
            {confirmText}
          </button>
          
          {showCancel && (
            <button
              onClick={onClose}
              className="w-full py-3 rounded-2xl bg-gray-50 text-gray-400 font-bold text-[14px] active:scale-95 transition-all duration-200 border border-gray-100"
            >
              {cancelText}
            </button>
          )}
        </div>
        
        {/* Close Button Top Right (Optional) */}
        {!showCancel && (
          <button 
            onClick={onClose}
            className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center text-gray-300 hover:text-gray-500 transition-colors"
          >
            <X size={20} />
          </button>
        )}
      </div>
    </div>
  );
}
