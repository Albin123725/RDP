import { Terminal, Code, FolderTree, GitBranch } from "lucide-react";
import { SiGithub } from "react-icons/si";
import { Card } from "@/components/ui/card";

export function WelcomeScreen() {
  return (
    <div className="h-full w-full flex items-center justify-center bg-background p-8">
      <div className="max-w-4xl w-full space-y-8">
        <div className="text-center space-y-4">
          <h1 className="text-4xl font-bold text-foreground">
            Welcome to DevSpace
          </h1>
          <p className="text-lg text-muted-foreground">
            A powerful web-based development environment with everything you need to code
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Card className="p-6 space-y-3">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-md bg-primary/10 flex items-center justify-center">
                <Terminal className="h-5 w-5 text-primary" />
              </div>
              <h3 className="text-lg font-semibold">Integrated Terminal</h3>
            </div>
            <p className="text-sm text-muted-foreground">
              Run commands directly in your browser with a full-featured terminal emulator
            </p>
          </Card>

          <Card className="p-6 space-y-3">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-md bg-primary/10 flex items-center justify-center">
                <Code className="h-5 w-5 text-primary" />
              </div>
              <h3 className="text-lg font-semibold">Code Editor</h3>
            </div>
            <p className="text-sm text-muted-foreground">
              Edit files with syntax highlighting powered by Monaco Editor
            </p>
          </Card>

          <Card className="p-6 space-y-3">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-md bg-primary/10 flex items-center justify-center">
                <FolderTree className="h-5 w-5 text-primary" />
              </div>
              <h3 className="text-lg font-semibold">File Manager</h3>
            </div>
            <p className="text-sm text-muted-foreground">
              Browse, create, edit, and delete files with an intuitive file tree interface
            </p>
          </Card>

          <Card className="p-6 space-y-3">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-md bg-primary/10 flex items-center justify-center">
                <SiGithub className="h-5 w-5 text-primary" />
              </div>
              <h3 className="text-lg font-semibold">GitHub Integration</h3>
            </div>
            <p className="text-sm text-muted-foreground">
              Browse your repositories, clone projects, and view files directly from GitHub
            </p>
          </Card>
        </div>

        <div className="text-center space-y-2">
          <p className="text-sm text-muted-foreground">
            Get started by opening a file from the file tree or exploring your GitHub repositories
          </p>
        </div>
      </div>
    </div>
  );
}
