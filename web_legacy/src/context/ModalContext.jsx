import React, { createContext, useContext, useState, useCallback } from 'react';
import Modal from '../components/Modal';

const ModalContext = createContext();

export const useModal = () => {
  const context = useContext(ModalContext);
  if (!context) {
    throw new Error('useModal must be used within a ModalProvider');
  }
  return context;
};

export const ModalProvider = ({ children }) => {
  const [modalState, setModalState] = useState({
    isOpen: false,
    title: '',
    message: '',
    type: 'info',
    confirmText: 'Tamam',
    cancelText: 'İptal',
    showCancel: true,
    onConfirm: () => {},
    onClose: () => {}
  });

  const showModal = useCallback((options) => {
    setModalState({
      isOpen: true,
      title: options.title || '',
      message: options.message || '',
      type: options.type || 'info',
      confirmText: options.confirmText || 'Tamam',
      cancelText: options.cancelText || 'İptal',
      showCancel: options.showCancel !== undefined ? options.showCancel : true,
      onConfirm: options.onConfirm || (() => {}),
      onClose: options.onClose || (() => {})
    });
  }, []);

  const hideModal = useCallback(() => {
    setModalState(prev => ({ ...prev, isOpen: false }));
  }, []);

  return (
    <ModalContext.Provider value={{ showModal, hideModal }}>
      {children}
      <Modal 
        {...modalState} 
        onClose={() => {
          modalState.onClose?.();
          hideModal();
        }}
      />
    </ModalContext.Provider>
  );
};
