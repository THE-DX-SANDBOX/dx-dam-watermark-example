// Designer Page - Main watermark spec editor

import { DesignerLayout } from '@/components/layout/DesignerLayout';
import { DesignerHeader } from '@/components/layout/DesignerHeader';
import { InputsPanel } from '@/components/panels/InputsPanel';
import { CanvasPanel } from '@/components/panels/CanvasPanel';
import { PropertiesPanel } from '@/components/panels/PropertiesPanel';
import { SpecProvider } from '@/state/SpecContext';
import { PreviewProvider } from '@/state/PreviewContext';

export default function Designer() {
  return (
    <SpecProvider>
      <PreviewProvider>
        <DesignerLayout
          header={<DesignerHeader />}
          leftPanel={<InputsPanel />}
          centerPanel={<CanvasPanel />}
          rightPanel={<PropertiesPanel />}
        />
      </PreviewProvider>
    </SpecProvider>
  );
}
