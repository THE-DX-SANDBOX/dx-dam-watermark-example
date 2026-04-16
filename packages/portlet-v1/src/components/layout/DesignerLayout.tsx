// Designer Layout - Three-column layout for the watermark designer

import { ReactNode } from 'react';

interface DesignerLayoutProps {
  leftPanel: ReactNode;
  centerPanel: ReactNode;
  rightPanel: ReactNode;
  header?: ReactNode;
}

export function DesignerLayout({ leftPanel, centerPanel, rightPanel, header }: DesignerLayoutProps) {
  return (
    <div className="h-screen flex flex-col bg-background overflow-hidden">
      {/* Header */}
      {header && (
        <div className="flex-shrink-0 border-b border-panel-border bg-card">
          {header}
        </div>
      )}

      {/* Main content area */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Panel - Inputs */}
        <div className="w-64 flex-shrink-0 panel overflow-hidden">
          {leftPanel}
        </div>

        {/* Center Panel - Canvas */}
        <div className="flex-1 flex flex-col overflow-hidden border-r border-panel-border">
          {centerPanel}
        </div>

        {/* Right Panel - Properties */}
        <div className="w-20 flex-shrink-0 panel overflow-hidden">
          {rightPanel}
        </div>
      </div>
    </div>
  );
}
