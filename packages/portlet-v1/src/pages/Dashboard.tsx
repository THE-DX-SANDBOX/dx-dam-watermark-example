// Dashboard Page - List specs and create new ones

import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Plus, FileText, Clock, Trash2, Edit, MoreHorizontal, AlertCircle, Loader2, CheckCircle2, Circle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import type { SpecMetadata, WatermarkSpec } from '@/spec/types';
import { createDefaultSpec } from '@/spec/types';
import { watermarkConfigApi, WatermarkConfigDB } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';

console.log('📊 [DASHBOARD] Dashboard module loaded');

// Convert DB record to SpecMetadata for display
function dbToMetadata(db: WatermarkConfigDB): SpecMetadata {
  const specData = db.spec_data as WatermarkSpec | null;
  return {
    specId: String(db.id), // Use DB ID as specId
    name: db.name,
    description: db.description,
    status: db.status,
    specVersion: db.version || '1.0.0',
    updatedAt: db.updated_at,
    layerCount: specData?.layers?.length || 0,
  };
}

export default function Dashboard() {
  console.log('📊 [DASHBOARD] Dashboard component rendering...');
  const navigate = useNavigate();
  const { toast } = useToast();
  const [specs, setSpecs] = useState<SpecMetadata[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load specs from API
  useEffect(() => {
    async function loadSpecs() {
      console.log('📊 [DASHBOARD] Loading specs from API...');
      setLoading(true);
      setError(null);
      
      try {
        const configs = await watermarkConfigApi.getAll();
        console.log('📊 [DASHBOARD] Loaded configs from API:', configs);
        
        const specList = configs.map(dbToMetadata);
        
        // Sort by updated date
        specList.sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
        console.log('📊 [DASHBOARD] Processed spec list:', specList);
        setSpecs(specList);
        console.log('✅ [DASHBOARD] Specs loaded successfully from API');
      } catch (err) {
        console.error('❌ [DASHBOARD] Failed to load specs from API:', err);
        setError(err instanceof Error ? err.message : 'Failed to load specs');
        toast({
          variant: 'destructive',
          title: 'Error loading specs',
          description: err instanceof Error ? err.message : 'Failed to connect to server',
        });
      } finally {
        setLoading(false);
      }
    }
    
    loadSpecs();
  }, [toast]);

  const handleCreateNew = async () => {
    try {
      const newSpec = createDefaultSpec('temp', 'New Watermark');
      
      // Create in database
      const created = await watermarkConfigApi.create({
        name: newSpec.name,
        description: newSpec.description,
        spec_data: newSpec,
        status: 'inactive',
        version: newSpec.specVersion,
      });
      
      console.log('✅ [DASHBOARD] Created new spec in DB:', created);
      toast({
        title: 'Spec created',
        description: `Created "${created.name}"`,
      });
      
      navigate(`/specs/${created.id}/edit`);
    } catch (err) {
      console.error('❌ [DASHBOARD] Failed to create spec:', err);
      toast({
        variant: 'destructive',
        title: 'Error creating spec',
        description: err instanceof Error ? err.message : 'Failed to create spec',
      });
    }
  };

  const handleDelete = async (specId: string) => {
    try {
      await watermarkConfigApi.delete(specId);
      setSpecs(specs.filter(s => s.specId !== specId));
      toast({
        title: 'Spec deleted',
        description: 'The watermark spec has been deleted.',
      });
    } catch (err) {
      console.error('❌ [DASHBOARD] Failed to delete spec:', err);
      toast({
        variant: 'destructive',
        title: 'Error deleting spec',
        description: err instanceof Error ? err.message : 'Failed to delete spec',
      });
    }
  };

  const handleSetActive = async (specId: string) => {
    try {
      // Deactivate all other specs first
      const updates = specs
        .filter(s => s.status === 'active' && s.specId !== specId)
        .map(s => watermarkConfigApi.update(s.specId, { status: 'inactive' }));
      
      await Promise.all(updates);
      
      // Activate the selected one
      await watermarkConfigApi.setActive(specId);
      
      // Refresh the list
      setSpecs(specs.map(s => ({
        ...s,
        status: s.specId === specId ? 'active' : 'inactive'
      })));
      
      toast({
        title: 'Spec activated',
        description: 'The watermark spec is now active.',
      });
    } catch (err) {
      console.error('❌ [DASHBOARD] Failed to set active:', err);
      toast({
        variant: 'destructive',
        title: 'Error setting active',
        description: err instanceof Error ? err.message : 'Failed to set spec as active',
      });
    }
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Loading state
  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
          <p className="text-muted-foreground">Loading watermark specs...</p>
        </div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Card className="max-w-md">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-destructive">
              <AlertCircle className="w-5 h-5" />
              Connection Error
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground mb-4">{error}</p>
            <Button onClick={() => window.location.reload()}>Retry</Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-panel-border bg-card">
        <div className="container max-w-5xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <FileText className="w-6 h-6 text-primary" />
              <h1 className="text-xl font-semibold">Watermark Spec Designer</h1>
            </div>
            <Button onClick={handleCreateNew}>
              <Plus className="w-4 h-4 mr-2" />
              New Spec
            </Button>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="container max-w-5xl mx-auto px-6 py-8">
        {specs.length === 0 ? (
          <Card className="border-dashed">
            <CardContent className="flex flex-col items-center justify-center py-16">
              <FileText className="w-12 h-12 text-muted-foreground mb-4" />
              <h3 className="text-lg font-medium mb-2">No specs yet</h3>
              <p className="text-sm text-muted-foreground mb-4">
                Create your first watermark specification to get started.
              </p>
              <Button onClick={handleCreateNew}>
                <Plus className="w-4 h-4 mr-2" />
                Create Spec
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {/* Create new card */}
            <button
              onClick={handleCreateNew}
              className="border-2 border-dashed border-border rounded-lg p-6 flex flex-col items-center justify-center text-muted-foreground hover:border-primary hover:text-primary transition-colors min-h-[160px]"
            >
              <Plus className="w-8 h-8 mb-2" />
              <span className="text-sm font-medium">New Spec</span>
            </button>

            {/* Spec cards */}
            {specs.map(spec => (
              <Card key={spec.specId} className="hover:shadow-md transition-shadow">
                <CardHeader className="pb-2">
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <CardTitle className="text-base truncate">{spec.name}</CardTitle>
                      <CardDescription className="text-xs mt-1">
                        v{spec.specVersion} · {spec.layerCount} layers
                      </CardDescription>
                    </div>
                    <div className="flex items-center gap-2">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                            <MoreHorizontal className="w-4 h-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem asChild>
                            <Link to={`/specs/${spec.specId}/edit`}>
                              <Edit className="w-4 h-4 mr-2" />
                              Edit
                            </Link>
                          </DropdownMenuItem>
                          <DropdownMenuItem 
                            onClick={() => handleDelete(spec.specId)}
                            className="text-destructive focus:text-destructive"
                          >
                            <Trash2 className="w-4 h-4 mr-2" />
                            Delete
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                      <Clock className="w-3.5 h-3.5" />
                      <span>{formatDate(spec.updatedAt)}</span>
                    </div>
                    <Button
                      variant="default" 
                      size="sm" 
                      asChild
                      className="h-7 text-xs"
                    >
                      <Link to={`/specs/${spec.specId}/edit`}>
                        <Edit className="w-3 h-3 mr-1.5" />
                        Manage
                      </Link>
                    </Button>
                  </div>
                  
                  {/* Active status toggle - radio button behavior */}
                  <div 
                    className={`flex items-center gap-2 p-2 rounded-md cursor-pointer transition-colors ${
                      spec.status === 'active' 
                        ? 'bg-green-50 border border-green-200 dark:bg-green-900/20 dark:border-green-800' 
                        : 'bg-muted/50 border border-transparent hover:bg-muted'
                    }`}
                    onClick={() => spec.status !== 'active' && handleSetActive(spec.specId)}
                  >
                    {spec.status === 'active' ? (
                      <CheckCircle2 className="w-4 h-4 text-green-600 dark:text-green-400 flex-shrink-0" />
                    ) : (
                      <Circle className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                    )}
                    <span className={`text-xs font-medium ${
                      spec.status === 'active' 
                        ? 'text-green-700 dark:text-green-300' 
                        : 'text-muted-foreground'
                    }`}>
                      {spec.status === 'active' ? 'Active Spec (in use)' : 'Click to set as active'}
                    </span>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        {/* Info section */}
        <div className="mt-12 p-6 rounded-lg bg-muted/50 border border-border">
          <h2 className="font-medium mb-2">About Watermark Spec Designer</h2>
          <p className="text-sm text-muted-foreground mb-4">
            Design deterministic watermark specifications for use with HCL DX. Specs are exported as JSON 
            and can be stored as DX JSON assets. A separate renderer/plugin applies the spec to uploaded 
            images to generate watermarked renditions.
          </p>
          <div className="flex flex-wrap gap-4 text-xs text-muted-foreground">
            <div>
              <strong className="text-foreground">Output Policy:</strong> Preserve input dimensions
            </div>
            <div>
              <strong className="text-foreground">Units:</strong> Normalized coordinates (0-1)
            </div>
            <div>
              <strong className="text-foreground">Formats:</strong> JPG, PNG, GIF, SVG
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
