// Spec Editor Wrapper - Loads spec by ID and provides context to designer

import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Loader2, AlertCircle } from 'lucide-react';
import { DesignerLayout } from '@/components/layout/DesignerLayout';
import { DesignerHeader } from '@/components/layout/DesignerHeader';
import { InputsPanel } from '@/components/panels/InputsPanel';
import { CanvasPanel } from '@/components/panels/CanvasPanel';
import { PropertiesPanel } from '@/components/panels/PropertiesPanel';
import { SpecProvider, useSpec } from '@/state/SpecContext';
import { PreviewProvider } from '@/state/PreviewContext';
import type { WatermarkSpec } from '@/spec/types';
import { createDefaultSpec } from '@/spec/types';
import { watermarkConfigApi } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

function SpecLoader() {
  const { specId } = useParams<{ specId: string }>();
  const navigate = useNavigate();
  const { dispatch } = useSpec();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadSpec() {
      if (!specId) {
        navigate('/');
        return;
      }

      setLoading(true);
      setError(null);

      try {
        // Load from API using the DB ID (UUID string)
        const dbConfig = await watermarkConfigApi.getById(specId);
        console.log('✅ [SPEC_EDITOR] Loaded spec from API:', dbConfig);
        
        // The spec_data contains the full WatermarkSpec
        let spec = dbConfig.spec_data as WatermarkSpec;
        
        // If spec_data is empty or invalid, create a default one
        if (!spec || !spec.specId) {
          spec = createDefaultSpec(dbConfig.id, dbConfig.name);
          spec.description = dbConfig.description;
          spec.status = dbConfig.status;
        }
        
        // Ensure specId matches DB ID for consistency
        spec.specId = String(dbConfig.id);
        
        dispatch({ type: 'LOAD_SPEC', payload: spec });
      } catch (err) {
        console.error('❌ [SPEC_EDITOR] Failed to load spec:', err);
        setError(err instanceof Error ? err.message : 'Failed to load spec');
      } finally {
        setLoading(false);
      }
    }

    loadSpec();
  }, [specId, dispatch, navigate]);

  if (loading) {
    return (
      <div className="h-screen flex items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
          <p className="text-muted-foreground">Loading spec...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-screen flex items-center justify-center bg-background">
        <Card className="max-w-md">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-destructive">
              <AlertCircle className="w-5 h-5" />
              Failed to Load Spec
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground mb-4">{error}</p>
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => navigate('/')}>Back to Dashboard</Button>
              <Button onClick={() => window.location.reload()}>Retry</Button>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <DesignerLayout
      header={<DesignerHeader />}
      leftPanel={<InputsPanel />}
      centerPanel={<CanvasPanel />}
      rightPanel={<PropertiesPanel />}
    />
  );
}

export default function SpecEditor() {
  return (
    <SpecProvider>
      <PreviewProvider>
        <SpecLoader />
      </PreviewProvider>
    </SpecProvider>
  );
}
