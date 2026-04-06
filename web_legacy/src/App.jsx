import React from 'react';
import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import TopNavigation from './components/TopNavigation';
import BottomNavigation from './components/BottomNavigation';
import CreateGig from './pages/CreateGig';
import Home from './pages/Home';
import Login from './pages/Login';
import Register from './pages/Register';
import Chat from './pages/Chat';
import Messages from './pages/Messages';
import Profile from './pages/Profile';
import MyGigs from './pages/MyGigs';
import UserProfile from './pages/UserProfile';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ModalProvider } from './context/ModalContext';
import { Navigate } from 'react-router-dom';

// Protected Route Component
const ProtectedRoute = ({ children }) => {
  const { currentUser } = useAuth();
  if (!currentUser) {
    return <Navigate to="/login" replace />;
  }
  return children;
};

// İç bileşen, böylece useLocation router bağlamı içinde çalışır
function Layout() {
  const location = useLocation();
  const isAuthPage = location.pathname === '/login' || location.pathname === '/register';

  return (
    <div className="mobile-app-container flex flex-col items-center shadow-[0_0_50px_rgba(0,0,0,0.1)] rounded-[32px] overflow-hidden my-4 sm:my-8 border-4 border-gray-100 relative">
      {!isAuthPage && <TopNavigation />}
      
      <div className={`w-full h-full bg-[#FAFAFC] ${!isAuthPage ? 'mobile-content-area' : 'overflow-hidden'}`}>
        <Routes>
          <Route path="/" element={<ProtectedRoute><Home /></ProtectedRoute>} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/chat/:roomId" element={<ProtectedRoute><Chat /></ProtectedRoute>} />
          <Route path="/messages" element={<ProtectedRoute><Messages /></ProtectedRoute>} />
          <Route path="/profile" element={<ProtectedRoute><Profile /></ProtectedRoute>} />
          <Route path="/my-gigs" element={<ProtectedRoute><MyGigs /></ProtectedRoute>} />
          <Route path="/user-profile/:userId" element={<ProtectedRoute><UserProfile /></ProtectedRoute>} />
          <Route path="/create-gig" element={<ProtectedRoute><CreateGig /></ProtectedRoute>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>

      {!isAuthPage && <BottomNavigation />}
    </div>
  );
}

function App() {
  return (
    <Router>
      <AuthProvider>
        <ModalProvider>
          {/* Masaüstünde Telefon Mockup'u gibi dursun diye arka planı hafif grileştiriyoruz index.css'den */}
          <Layout />
        </ModalProvider>
      </AuthProvider>
    </Router>
  );
}

export default App;
