import React from 'react';
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Routes, Route } from "react-router-dom";
import Dashboard from "./pages/Dashboard";
import SpecEditor from "./pages/SpecEditor";
import NotFound from "./pages/NotFound";

console.log('📦 [APP] App component module loaded');

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    console.error('🔥 [ERROR BOUNDARY] Caught error:', error);
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('🔥 [ERROR BOUNDARY] Error details:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: '20px', background: '#fee', border: '2px solid #f00', margin: '20px', fontFamily: 'monospace' }}>
          <h2 style={{ color: '#c00' }}>❌ Application Error</h2>
          <p><strong>Error:</strong> {this.state.error?.message}</p>
          <pre style={{ background: '#fff', padding: '10px', overflow: 'auto' }}>
            {this.state.error?.stack}
          </pre>
          <button 
            onClick={() => window.location.reload()} 
            style={{ padding: '10px 20px', marginTop: '10px', cursor: 'pointer' }}
          >
            Reload Page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

const App = () => {
  console.log('🎨 [APP] App component rendering...');
  
  React.useEffect(() => {
    console.log('✅ [APP] App component mounted');
    console.log('🌐 [APP] Current location:', window.location.href);
    console.log('🌐 [APP] Hash:', window.location.hash);
    return () => {
      console.log('👋 [APP] App component unmounting');
    };
  }, []);
  
  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <TooltipProvider>
          <Toaster />
          <Sonner />
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/specs/:specId/edit" element={<SpecEditor />} />
            {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
            <Route path="*" element={<NotFound />} />
          </Routes>
        </TooltipProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  );
};

export default App;
