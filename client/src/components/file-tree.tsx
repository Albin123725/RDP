import { useState } from "react";
import { ChevronRight, ChevronDown, File, Folder, FolderOpen } from "lucide-react";
import { FileNode } from "@shared/schema";
import { cn } from "@/lib/utils";

interface FileTreeProps {
  nodes: FileNode[];
  onFileSelect: (path: string) => void;
  selectedPath?: string;
  level?: number;
}

export function FileTree({ nodes, onFileSelect, selectedPath, level = 0 }: FileTreeProps) {
  return (
    <div className="w-full">
      {nodes.map((node) => (
        <FileTreeNode
          key={node.path}
          node={node}
          onFileSelect={onFileSelect}
          selectedPath={selectedPath}
          level={level}
        />
      ))}
    </div>
  );
}

interface FileTreeNodeProps {
  node: FileNode;
  onFileSelect: (path: string) => void;
  selectedPath?: string;
  level: number;
}

function FileTreeNode({ node, onFileSelect, selectedPath, level }: FileTreeNodeProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const isDirectory = node.type === 'directory';
  const isSelected = selectedPath === node.path;

  const handleClick = () => {
    if (isDirectory) {
      setIsExpanded(!isExpanded);
    } else {
      onFileSelect(node.path);
    }
  };

  return (
    <div>
      <div
        className={cn(
          "flex items-center gap-2 py-1.5 px-3 text-sm cursor-pointer hover-elevate active-elevate-2 rounded-sm",
          isSelected && "bg-sidebar-accent text-sidebar-accent-foreground"
        )}
        style={{ paddingLeft: `${level * 16 + 12}px` }}
        onClick={handleClick}
        data-testid={`file-tree-${node.type}-${node.name}`}
      >
        {isDirectory && (
          <span className="flex-shrink-0">
            {isExpanded ? (
              <ChevronDown className="h-4 w-4" />
            ) : (
              <ChevronRight className="h-4 w-4" />
            )}
          </span>
        )}
        {!isDirectory && <span className="w-4" />}
        <span className="flex-shrink-0">
          {isDirectory ? (
            isExpanded ? (
              <FolderOpen className="h-4 w-4 text-primary" />
            ) : (
              <Folder className="h-4 w-4 text-primary" />
            )
          ) : (
            <File className="h-4 w-4 text-muted-foreground" />
          )}
        </span>
        <span className="truncate flex-1">{node.name}</span>
      </div>
      {isDirectory && isExpanded && node.children && (
        <FileTree
          nodes={node.children}
          onFileSelect={onFileSelect}
          selectedPath={selectedPath}
          level={level + 1}
        />
      )}
    </div>
  );
}
