import { useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { Panel, PanelGroup, PanelResizeHandle } from "react-resizable-panels";
import { Menu, FolderOpen, Plus, Upload, Download, Trash2, Save, AlertCircle } from "lucide-react";
import { FileTree } from "@/components/file-tree";
import { GitHubSidebar } from "@/components/github-sidebar";
import { WorkspaceTabs } from "@/components/workspace-tabs";
import { Terminal } from "@/components/terminal";
import { CodeEditor } from "@/components/code-editor";
import { StatusBar } from "@/components/status-bar";
import { WelcomeScreen } from "@/components/welcome-screen";
import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import { apiRequest, queryClient } from "@/lib/queryClient";
import { FileNode, Tab, GitHubRepo } from "@shared/schema";

export default function Workspace() {
  const [leftSidebarOpen, setLeftSidebarOpen] = useState(true);
  const [rightSidebarOpen, setRightSidebarOpen] = useState(true);
  const [tabs, setTabs] = useState<Tab[]>([
    { id: 'welcome', type: 'welcome', title: 'Welcome' }
  ]);
  const [activeTabId, setActiveTabId] = useState('welcome');
  const [fileContents, setFileContents] = useState<Record<string, string>>({});
  const [modifiedFiles, setModifiedFiles] = useState<Set<string>>(new Set());
  const { toast } = useToast();

  const { data: fileTree, isLoading: isLoadingFiles } = useQuery<FileNode[]>({
    queryKey: ['/api/files'],
    enabled: true,
  });

  const saveFileMutation = useMutation({
    mutationFn: async ({ path, content }: { path: string; content: string }) => {
      return await apiRequest('POST', '/api/files/write', { path, content });
    },
    onSuccess: (_, variables) => {
      setModifiedFiles(prev => {
        const newSet = new Set(prev);
        newSet.delete(variables.path);
        return newSet;
      });
      toast({
        title: "File saved",
        description: `Successfully saved ${variables.path.split('/').pop()}`,
      });
      queryClient.invalidateQueries({ queryKey: ['/api/files'] });
    },
    onError: (error: any) => {
      toast({
        title: "Error saving file",
        description: error.message,
        variant: "destructive",
      });
    },
  });

  const handleFileSelect = async (path: string) => {
    const existingTab = tabs.find(tab => tab.filePath === path);
    
    if (existingTab) {
      setActiveTabId(existingTab.id);
      return;
    }

    const fileName = path.split('/').pop() || path;
    const extension = fileName.split('.').pop() || '';
    const languageMap: Record<string, string> = {
      js: 'javascript',
      jsx: 'javascript',
      ts: 'typescript',
      tsx: 'typescript',
      py: 'python',
      html: 'html',
      css: 'css',
      json: 'json',
      md: 'markdown',
      yaml: 'yaml',
      yml: 'yaml',
    };

    const newTab: Tab = {
      id: `file-${Date.now()}`,
      type: 'editor',
      title: fileName,
      filePath: path,
      language: languageMap[extension] || 'plaintext',
    };

    setTabs([...tabs, newTab]);
    setActiveTabId(newTab.id);

    if (!fileContents[path]) {
      try {
        const response = await fetch(`/api/files/read?path=${encodeURIComponent(path)}`);
        if (response.ok) {
          const data = await response.json();
          setFileContents(prev => ({ ...prev, [path]: data.content }));
        } else {
          toast({
            title: "Error loading file",
            description: "Failed to read file contents",
            variant: "destructive",
          });
        }
      } catch (error) {
        console.error('Error loading file:', error);
        toast({
          title: "Error loading file",
          description: "An error occurred while loading the file",
          variant: "destructive",
        });
      }
    }
  };

  const handleTabClose = (tabId: string) => {
    const tab = tabs.find(t => t.id === tabId);
    
    if (tab?.filePath && modifiedFiles.has(tab.filePath)) {
      const confirmed = window.confirm(`${tab.title} has unsaved changes. Close anyway?`);
      if (!confirmed) return;
    }

    const newTabs = tabs.filter(t => t.id !== tabId);
    setTabs(newTabs);
    
    if (activeTabId === tabId) {
      const activeIndex = tabs.findIndex(t => t.id === tabId);
      const newActiveTab = newTabs[Math.max(0, activeIndex - 1)];
      setActiveTabId(newActiveTab?.id || '');
    }
  };

  const handleNewTerminal = () => {
    const terminalId = `terminal-${Date.now()}`;
    const newTab: Tab = {
      id: terminalId,
      type: 'terminal',
      title: 'Terminal',
      terminalId,
    };
    setTabs([...tabs, newTab]);
    setActiveTabId(newTab.id);
  };

  const handleRepoSelect = (repo: GitHubRepo) => {
    toast({
      title: "Repository selected",
      description: `${repo.full_name} - Clone functionality coming soon`,
    });
  };

  const handleFileContentChange = (path: string, content: string | undefined) => {
    if (content !== undefined) {
      setFileContents(prev => ({ ...prev, [path]: content }));
      setModifiedFiles(prev => new Set(prev).add(path));
      
      const tab = tabs.find(t => t.filePath === path);
      if (tab && !tab.title.startsWith('● ')) {
        setTabs(tabs.map(t => 
          t.id === tab.id ? { ...t, title: `● ${t.title}` } : t
        ));
      }
    }
  };

  const handleSaveFile = () => {
    const activeTab = tabs.find(tab => tab.id === activeTabId);
    if (activeTab?.filePath && fileContents[activeTab.filePath]) {
      saveFileMutation.mutate({
        path: activeTab.filePath,
        content: fileContents[activeTab.filePath],
      });
      
      if (activeTab.title.startsWith('● ')) {
        setTabs(tabs.map(t => 
          t.id === activeTab.id ? { ...t, title: t.title.slice(2) } : t
        ));
      }
    }
  };

  const activeTab = tabs.find(tab => tab.id === activeTabId);
  const currentFile = activeTab?.filePath;
  const isModified = currentFile ? modifiedFiles.has(currentFile) : false;

  return (
    <div className="h-screen w-screen flex flex-col overflow-hidden bg-background">
      <div className="h-12 bg-sidebar border-b border-sidebar-border flex items-center justify-between px-4 flex-shrink-0">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setLeftSidebarOpen(!leftSidebarOpen)}
            data-testid="button-toggle-left-sidebar"
          >
            <Menu className="h-4 w-4" />
          </Button>
          <Separator orientation="vertical" className="h-6" />
          <h1 className="text-sm font-semibold">DevSpace</h1>
        </div>
        <div className="flex items-center gap-2">
          {activeTab?.type === 'editor' && (
            <>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleSaveFile}
                disabled={!isModified || saveFileMutation.isPending}
                data-testid="button-save-file"
              >
                <Save className="h-4 w-4 mr-2" />
                {saveFileMutation.isPending ? 'Saving...' : 'Save'}
              </Button>
              <Separator orientation="vertical" className="h-6" />
            </>
          )}
          <Button
            variant="ghost"
            size="sm"
            onClick={handleNewTerminal}
            data-testid="button-new-terminal"
          >
            <Plus className="h-4 w-4 mr-2" />
            New Terminal
          </Button>
          <Separator orientation="vertical" className="h-6" />
          <ThemeToggle />
        </div>
      </div>

      <div className="flex-1 overflow-hidden">
        <PanelGroup direction="horizontal">
          {leftSidebarOpen && (
            <>
              <Panel defaultSize={20} minSize={15} maxSize={35} id="left-sidebar">
                <div className="h-full flex flex-col bg-sidebar border-r border-sidebar-border">
                  <div className="p-4 border-b border-sidebar-border">
                    <div className="flex items-center justify-between mb-3">
                      <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                        Explorer
                      </h2>
                      <div className="flex items-center gap-1">
                        <Button variant="ghost" size="icon" className="h-6 w-6" data-testid="button-new-file">
                          <Plus className="h-3 w-3" />
                        </Button>
                        <Button variant="ghost" size="icon" className="h-6 w-6" data-testid="button-upload-file">
                          <Upload className="h-3 w-3" />
                        </Button>
                      </div>
                    </div>
                  </div>
                  <ScrollArea className="flex-1">
                    {isLoadingFiles ? (
                      <div className="p-3 space-y-2">
                        {[1, 2, 3, 4, 5].map((i) => (
                          <Skeleton key={i} className="h-8 w-full" />
                        ))}
                      </div>
                    ) : fileTree && fileTree.length > 0 ? (
                      <FileTree
                        nodes={fileTree}
                        onFileSelect={handleFileSelect}
                        selectedPath={currentFile}
                      />
                    ) : (
                      <div className="p-4 text-center text-sm text-muted-foreground">
                        No files available
                      </div>
                    )}
                  </ScrollArea>
                </div>
              </Panel>
              <PanelResizeHandle className="w-1 bg-border hover:bg-primary/50 transition-colors" />
            </>
          )}

          <Panel defaultSize={60} minSize={30} id="main-panel">
            <div className="h-full flex flex-col">
              <WorkspaceTabs
                tabs={tabs}
                activeTabId={activeTabId}
                onTabClick={setActiveTabId}
                onTabClose={handleTabClose}
              />
              <div className="flex-1 overflow-hidden">
                {activeTab?.type === 'welcome' && <WelcomeScreen />}
                {activeTab?.type === 'editor' && activeTab.filePath && (
                  <CodeEditor
                    value={fileContents[activeTab.filePath] || ''}
                    onChange={(value) => handleFileContentChange(activeTab.filePath!, value)}
                    language={activeTab.language}
                    path={activeTab.filePath}
                  />
                )}
                {activeTab?.type === 'terminal' && activeTab.terminalId && (
                  <Terminal terminalId={activeTab.terminalId} />
                )}
              </div>
            </div>
          </Panel>

          {rightSidebarOpen && (
            <>
              <PanelResizeHandle className="w-1 bg-border hover:bg-primary/50 transition-colors" />
              <Panel defaultSize={20} minSize={15} maxSize={35} id="right-sidebar">
                <GitHubSidebar onRepoSelect={handleRepoSelect} />
              </Panel>
            </>
          )}
        </PanelGroup>
      </div>

      <StatusBar
        connectedToGitHub={true}
        currentFile={currentFile}
        terminalStatus={tabs.some(t => t.type === 'terminal') ? 'Ready' : undefined}
      />
    </div>
  );
}
