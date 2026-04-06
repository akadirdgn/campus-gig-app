import React from 'react';
import { useAuth } from '../context/AuthContext';

export default function Navbar() {
  const { userData } = useAuth();

  return (
    <nav className="fixed top-0 w-full z-50 bg-campus-darkBg/80 backdrop-blur-md border-b border-white/10 px-6 py-4 flex justify-between items-center rounded-b-2xl">
      <div className="text-2xl font-bold text-white tracking-tight">
        Campus<span className="text-campus-indigo">Gig</span>
      </div>
      
      {userData && (
        <div className="flex items-center gap-4 bg-white/10 px-4 py-2 rounded-xl backdrop-blur-sm">
          <span className="text-sm text-gray-300 font-medium">Bakiye:</span>
          <span className="text-campus-mint font-bold flex items-center gap-1">
             {userData.balance_tokens} <span className="text-xs text-white">CGT</span>
          </span>
        </div>
      )}
    </nav>
  );
}
