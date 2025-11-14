import { SiGithub } from "react-icons/si";
import { Terminal, FileText } from "lucide-react";

interface StatusBarProps {
  connectedToGitHub: boolean;
  currentFile?: string;
  terminalStatus?: string;
}

export function StatusBar({ connectedToGitHub, currentFile, terminalStatus }: StatusBarProps) {
  return (
    <div className="h-8 bg-sidebar border-t border-sidebar-border flex items-center justify-between px-4 text-xs">
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          <SiGithub className="h-3 w-3" />
          <span className={connectedToGitHub ? "text-status-online" : "text-muted-foreground"}>
            {connectedToGitHub ? 'Connected' : 'Disconnected'}
          </span>
        </div>
        {currentFile && (
          <>
            <span className="text-muted-foreground">|</span>
            <div className="flex items-center gap-2">
              <FileText className="h-3 w-3" />
              <span className="text-muted-foreground truncate max-w-64">{currentFile}</span>
            </div>
          </>
        )}
      </div>
      <div className="flex items-center gap-4">
        {terminalStatus && (
          <div className="flex items-center gap-2">
            <Terminal className="h-3 w-3" />
            <span className="text-muted-foreground">{terminalStatus}</span>
          </div>
        )}
        <span className="text-muted-foreground">DevSpace v1.0</span>
      </div>
    </div>
  );
}
