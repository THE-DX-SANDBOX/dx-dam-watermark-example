import React from 'react';
import { createRoot } from "react-dom/client";
import { HashRouter } from 'react-router-dom';
import App from "./App.tsx";
import "./index.css";

console.log('🚀 [MAIN] Starting Water Muse application...');
console.log('🚀 [MAIN] React version:', React.version);
console.log('🚀 [MAIN] Environment:', import.meta.env.MODE);

// Get root element ID from environment (for DX Script Portlet)
const ROOT_ELEMENT_ID = import.meta.env.VITE_ROOT_ELEMENT_ID || 'dx-scriptapp-dam-demo-root';
console.log('🔍 [MAIN] Looking for root element:', ROOT_ELEMENT_ID);

// Check if DOM is ready
if (document.readyState === 'loading') {
  console.log('⏳ [MAIN] DOM is still loading, waiting for DOMContentLoaded...');
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  console.log('✅ [MAIN] DOM is ready, initializing app immediately');
  initApp();
}

function initApp() {
  console.log('🎯 [MAIN] Initializing app...');
  console.log('🔍 [MAIN] Document body:', document.body);
  console.log('🔍 [MAIN] All elements with ID:', Array.from(document.querySelectorAll('[id]')).map(el => el.id));
  
  const rootElement = document.getElementById(ROOT_ELEMENT_ID);
  console.log('🔍 [MAIN] Root element found:', rootElement);
  
  if (!rootElement) {
    console.error('❌ [MAIN] Root element #' + ROOT_ELEMENT_ID + ' not found!');
    console.error('❌ [MAIN] Available IDs in document:', Array.from(document.querySelectorAll('[id]')).map(el => el.id));
    console.error('❌ [MAIN] Document body innerHTML:', document.body.innerHTML);
    
    // Create fallback error UI
    const errorDiv = document.createElement('div');
    errorDiv.style.cssText = 'padding: 20px; background: #fee; border: 2px solid #f00; margin: 20px; font-family: monospace;';
    errorDiv.innerHTML = `
      <h2 style="color: #c00;">❌ Water Muse Failed to Load</h2>
      <p><strong>Error:</strong> Root element #${ROOT_ELEMENT_ID} not found</p>
      <p><strong>Available elements:</strong> ${Array.from(document.querySelectorAll('[id]')).map(el => el.id).join(', ') || 'None'}</p>
      <p><strong>Document ready state:</strong> ${document.readyState}</p>
      <p><strong>Expected ID:</strong> ${ROOT_ELEMENT_ID}</p>
    `;
    document.body.appendChild(errorDiv);
    throw new Error(`Root element #${ROOT_ELEMENT_ID} not found`);
  }
  
  console.log('✅ [MAIN] Root element found successfully');
  console.log('🔨 [MAIN] Creating React root...');
  
  try {
    const root = createRoot(rootElement);
    console.log('✅ [MAIN] React root created');
    console.log('🎨 [MAIN] Rendering app...');
    
    root.render(
      <React.StrictMode>
        <HashRouter>
          <App />
        </HashRouter>
      </React.StrictMode>
    );
    
    console.log('✅ [MAIN] App rendered successfully!');
  } catch (error) {
    console.error('❌ [MAIN] Error during render:', error);
    throw error;
  }
}
