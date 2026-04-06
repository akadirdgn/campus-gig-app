import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";
import { getFunctions } from "firebase/functions";

const firebaseConfig = {
  apiKey: "AIzaSyCgNobdNOWrvCzn2acfQGFph-EL5UXiOd8",
  authDomain: "campusgig-da185.firebaseapp.com",
  projectId: "campusgig-da185",
  storageBucket: "campusgig-da185.firebasestorage.app",
  messagingSenderId: "309528319407",
  appId: "1:309528319407:web:56c0237e359ddcd2368b5a"
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const functions = getFunctions(app);
