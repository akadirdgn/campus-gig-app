import React, { createContext, useContext, useEffect, useState } from 'react';
import { auth, db } from '../firebase';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, onSnapshot } from 'firebase/firestore';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [currentUser, setCurrentUser] = useState(null);
  const [userData, setUserData] = useState(null);
  const [loading, setLoading] = useState(true);

  const logout = () => {
    return signOut(auth);
  };

  useEffect(() => {
    const unsubscribeAuth = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      
      if (user) {
        const unSubDoc = onSnapshot(doc(db, 'users', user.uid), (docSnap) => {
          if (docSnap.exists()) setUserData(docSnap.data());
          setLoading(false);
        });
        return () => unSubDoc();
      } else {
        setUserData(null);
        setLoading(false);
      }
    });

    return () => unsubscribeAuth();
  }, []);

  return (
    <AuthContext.Provider value={{ currentUser, userData, logout }}>
      {!loading ? children : <LoadingScreen />}
    </AuthContext.Provider>
  );
};

const LoadingScreen = () => (
    <div className="flex h-screen w-full items-center justify-center bg-campus-darkBg z-50 fixed inset-0">
        <div className="w-12 h-12 border-4 border-campus-mint border-t-transparent rounded-full animate-spin"></div>
    </div>
);
