import Editor from "@monaco-editor/react";
import { useTheme } from "./theme-provider";
import { Skeleton } from "@/components/ui/skeleton";

interface CodeEditorProps {
  value: string;
  onChange?: (value: string | undefined) => void;
  language?: string;
  path?: string;
  readOnly?: boolean;
}

export function CodeEditor({ value, onChange, language = "plaintext", path, readOnly = false }: CodeEditorProps) {
  const { theme } = useTheme();

  return (
    <Editor
      height="100%"
      defaultLanguage={language}
      language={language}
      value={value}
      onChange={onChange}
      theme={theme === "dark" ? "vs-dark" : "light"}
      path={path}
      options={{
        minimap: { enabled: true },
        fontSize: 14,
        fontFamily: 'JetBrains Mono, Fira Code, monospace',
        lineNumbers: 'on',
        rulers: [],
        scrollBeyondLastLine: false,
        automaticLayout: true,
        tabSize: 2,
        readOnly,
      }}
      loading={
        <div className="h-full w-full flex items-center justify-center bg-card">
          <div className="space-y-3 w-full max-w-2xl px-6">
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-5/6" />
            <Skeleton className="h-4 w-4/6" />
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-3/6" />
          </div>
        </div>
      }
    />
  );
}
