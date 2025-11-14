import { X } from "lucide-react";
import { Tab } from "@shared/schema";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { ScrollArea, ScrollBar } from "@/components/ui/scroll-area";

interface WorkspaceTabsProps {
  tabs: Tab[];
  activeTabId: string;
  onTabClick: (tabId: string) => void;
  onTabClose: (tabId: string) => void;
}

export function WorkspaceTabs({ tabs, activeTabId, onTabClick, onTabClose }: WorkspaceTabsProps) {
  return (
    <div className="h-12 flex items-center bg-card border-b border-border">
      <ScrollArea className="flex-1">
        <div className="flex items-center h-12">
          {tabs.map((tab) => (
            <div
              key={tab.id}
              className={cn(
                "group h-full flex items-center gap-2 px-4 border-r border-border cursor-pointer hover-elevate active-elevate-2 relative min-w-32 max-w-64",
                activeTabId === tab.id && "bg-background"
              )}
              onClick={() => onTabClick(tab.id)}
              data-testid={`tab-${tab.id}`}
            >
              <span className="text-sm truncate flex-1">
                {tab.title}
              </span>
              <Button
                variant="ghost"
                size="icon"
                className="h-5 w-5 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                onClick={(e) => {
                  e.stopPropagation();
                  onTabClose(tab.id);
                }}
                data-testid={`button-close-tab-${tab.id}`}
              >
                <X className="h-3 w-3" />
              </Button>
              {activeTabId === tab.id && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary" />
              )}
            </div>
          ))}
        </div>
        <ScrollBar orientation="horizontal" />
      </ScrollArea>
    </div>
  );
}
