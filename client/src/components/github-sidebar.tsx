import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { GitBranch, Star, GitFork, ExternalLink, Search, Loader2 } from "lucide-react";
import { SiGithub } from "react-icons/si";
import { GitHubRepo } from "@shared/schema";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Skeleton } from "@/components/ui/skeleton";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";

interface GitHubSidebarProps {
  onRepoSelect?: (repo: GitHubRepo) => void;
}

export function GitHubSidebar({ onRepoSelect }: GitHubSidebarProps) {
  const [searchQuery, setSearchQuery] = useState("");

  const { data: repos, isLoading } = useQuery<GitHubRepo[]>({
    queryKey: ['/api/github/repos'],
    enabled: true,
  });

  const filteredRepos = repos?.filter(repo =>
    repo.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    repo.description?.toLowerCase().includes(searchQuery.toLowerCase())
  ) || [];

  return (
    <div className="h-full flex flex-col bg-sidebar border-l border-sidebar-border">
      <div className="p-4 border-b border-sidebar-border">
        <div className="flex items-center gap-3 mb-4">
          <SiGithub className="h-5 w-5 text-sidebar-foreground" />
          <h2 className="text-sm font-semibold text-sidebar-foreground">GitHub Repositories</h2>
        </div>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            type="search"
            placeholder="Search repositories..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 bg-sidebar-accent border-sidebar-border h-9"
            data-testid="input-repo-search"
          />
        </div>
      </div>

      <ScrollArea className="flex-1">
        <div className="p-3 space-y-2">
          {isLoading ? (
            <>
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="p-3 space-y-2 bg-sidebar-accent rounded-md">
                  <Skeleton className="h-4 w-3/4" />
                  <Skeleton className="h-3 w-full" />
                  <Skeleton className="h-3 w-1/2" />
                </div>
              ))}
            </>
          ) : filteredRepos.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground text-sm">
              {searchQuery ? 'No repositories found' : 'No repositories available'}
            </div>
          ) : (
            filteredRepos.map((repo) => (
              <RepoCard
                key={repo.id}
                repo={repo}
                onClick={() => onRepoSelect?.(repo)}
              />
            ))
          )}
        </div>
      </ScrollArea>
    </div>
  );
}

interface RepoCardProps {
  repo: GitHubRepo;
  onClick?: () => void;
}

function RepoCard({ repo, onClick }: RepoCardProps) {
  return (
    <div
      className="p-3 rounded-md bg-card border border-card-border hover-elevate active-elevate-2 cursor-pointer transition-colors"
      onClick={onClick}
      data-testid={`repo-card-${repo.name}`}
    >
      <div className="flex items-start gap-3 mb-2">
        <Avatar className="h-8 w-8 flex-shrink-0">
          <AvatarImage src={repo.owner.avatar_url} alt={repo.owner.login} />
          <AvatarFallback>{repo.owner.login[0].toUpperCase()}</AvatarFallback>
        </Avatar>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <h3 className="text-sm font-medium text-card-foreground truncate">
              {repo.name}
            </h3>
            <Button
              variant="ghost"
              size="icon"
              className="h-6 w-6 flex-shrink-0"
              onClick={(e) => {
                e.stopPropagation();
                window.open(repo.html_url, '_blank');
              }}
              data-testid={`button-open-repo-${repo.name}`}
            >
              <ExternalLink className="h-3 w-3" />
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">{repo.owner.login}</p>
        </div>
      </div>
      {repo.description && (
        <p className="text-xs text-muted-foreground mb-2 line-clamp-2">
          {repo.description}
        </p>
      )}
      <div className="flex items-center gap-3 text-xs text-muted-foreground">
        <div className="flex items-center gap-1">
          <GitBranch className="h-3 w-3" />
          <span>{repo.default_branch}</span>
        </div>
        <span>•</span>
        <span>{new Date(repo.updated_at).toLocaleDateString()}</span>
      </div>
    </div>
  );
}
