// Designer Header - Top bar with spec info and actions

import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Save, Download, Upload, FileText, MoreHorizontal, Eye, Check, ArrowLeft, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { useSpec } from '@/state/SpecContext';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { watermarkConfigApi } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';

export function DesignerHeader() {
  const { state, dispatch } = useSpec();
  const { spec, isDirty } = state;
  const [showJsonModal, setShowJsonModal] = useState(false);
  const [saving, setSaving] = useState(false);
  const { toast } = useToast();

  const handleNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    dispatch({ type: 'UPDATE_SPEC_NAME', payload: e.target.value });
  };

  const handleExportJson = () => {
    const json = JSON.stringify(spec, null, 2);
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${spec.name.toLowerCase().replace(/\s+/g, '-')}-spec.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleSaveDraft = async () => {
    setSaving(true);
    try {
      // Save to API using the specId (which is the DB UUID)
      await watermarkConfigApi.update(spec.specId, {
        name: spec.name,
        description: spec.description,
        spec_data: spec,
        status: spec.status,
        version: spec.specVersion,
      });
      
      dispatch({ type: 'MARK_SAVED' });
      toast({
        title: 'Saved',
        description: 'Your changes have been saved.',
      });
    } catch (err) {
      console.error('❌ [HEADER] Failed to save:', err);
      toast({
        variant: 'destructive',
        title: 'Save failed',
        description: err instanceof Error ? err.message : 'Failed to save changes',
      });
    } finally {
      setSaving(false);
    }
  };

  const handleSetActive = async () => {
    try {
      await watermarkConfigApi.setActive(spec.specId);
      dispatch({ type: 'SET_STATUS', payload: 'active' });
      toast({
        title: 'Activated',
        description: 'This spec is now the active watermark configuration.',
      });
    } catch (err) {
      console.error('❌ [HEADER] Failed to set active:', err);
      toast({
        variant: 'destructive',
        title: 'Activation failed',
        description: err instanceof Error ? err.message : 'Failed to activate spec',
      });
    }
  };

  return (
    <div className="h-12 px-4 flex items-center justify-between gap-4">
      {/* Left: Back button, Logo and spec name */}
      <div className="flex items-center gap-4">
        <Link to="/" className="flex items-center justify-center w-8 h-8 rounded-md hover:bg-muted transition-colors">
          <ArrowLeft className="w-4 h-4" />
        </Link>
        
        <div className="flex items-center gap-2">
          <FileText className="w-5 h-5 text-primary" />
          <span className="font-semibold text-sm">Watermark Designer</span>
        </div>

        <div className="h-5 w-px bg-border" />

        <div className="flex items-center gap-2">
          <Input
            value={spec.name}
            onChange={handleNameChange}
            className="h-7 w-48 text-sm font-medium bg-transparent border-transparent hover:border-input focus:border-input transition-colors"
          />
          {spec.status === 'active' && (
            <Badge className="text-xs bg-green-500 hover:bg-green-600 text-white">
              Active
            </Badge>
          )}
          {isDirty && (
            <span className="w-2 h-2 rounded-full bg-tool-warning" title="Unsaved changes" />
          )}
        </div>
      </div>

      {/* Center: Version info */}
      <div className="text-xs text-muted-foreground">
        v{spec.specVersion} · Schema v{spec.schemaVersion}
      </div>

      {/* Right: Actions */}
      <div className="flex items-center gap-2">
        <Button variant="outline" size="sm" onClick={handleSaveDraft} disabled={saving} className="h-8">
          {saving ? (
            <Loader2 className="w-4 h-4 mr-1.5 animate-spin" />
          ) : (
            <Save className="w-4 h-4 mr-1.5" />
          )}
          {saving ? 'Saving...' : 'Save Draft'}
        </Button>

        <Button variant="default" size="sm" onClick={handleExportJson} className="h-8">
          <Download className="w-4 h-4 mr-1.5" />
          Export JSON
        </Button>

        <Button variant="outline" size="sm" onClick={() => setShowJsonModal(true)} className="h-8">
          <Eye className="w-4 h-4 mr-1.5" />
          View JSON
        </Button>

        <Dialog open={showJsonModal} onOpenChange={setShowJsonModal}>
          <DialogContent className="max-w-3xl max-h-[80vh]">
            <DialogHeader>
              <DialogTitle>Spec JSON</DialogTitle>
            </DialogHeader>
            <ScrollArea className="h-[60vh]">
              <pre className="text-xs bg-muted p-4 rounded-md overflow-x-auto">
                {JSON.stringify(spec, null, 2)}
              </pre>
            </ScrollArea>
          </DialogContent>
        </Dialog>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
              <MoreHorizontal className="w-4 h-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem>
              <Upload className="w-4 h-4 mr-2" />
              Import Spec
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={() => dispatch({ type: 'INCREMENT_VERSION' })}>
              Increment Version
            </DropdownMenuItem>
            {spec.status !== 'active' && (
              <DropdownMenuItem onClick={handleSetActive}>
                <Check className="w-4 h-4 mr-2" />
                Set as Active
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  );
}
