import type { Express } from "express";
import { createServer, type Server } from "http";
import { WebSocketServer } from "ws";
import { promises as fs } from "fs";
import { exec, spawn } from "child_process";
import { promisify } from "util";
import path from "path";
import multer from "multer";
import { getUncachableGitHubClient } from "./github";
import { storage } from "./storage";

const execAsync = promisify(exec);

const upload = multer({ dest: '/tmp/uploads/' });

const WORKSPACE_ROOT = process.cwd();
const MAX_DEPTH = 10;

export async function registerRoutes(app: Express): Promise<Server> {
  const httpServer = createServer(app);

  // WebSocket server for terminal I/O with persistent shell sessions
  const wss = new WebSocketServer({ 
    server: httpServer, 
    path: '/ws/terminal' 
  });

  wss.on('connection', (ws) => {
    console.log('Terminal WebSocket connected');

    const shell = spawn('/bin/bash', ['-i'], {
      cwd: WORKSPACE_ROOT,
      env: { ...process.env, TERM: 'xterm-256color' },
    });

    shell.stdout.on('data', (data: Buffer) => {
      ws.send(JSON.stringify({ type: 'output', data: data.toString() }));
    });

    shell.stderr.on('data', (data: Buffer) => {
      ws.send(JSON.stringify({ type: 'error', data: data.toString() }));
    });

    shell.on('exit', (code: number) => {
      ws.send(JSON.stringify({ 
        type: 'error', 
        data: `\r\nShell exited with code ${code}\r\n`
      }));
      ws.close();
    });

    ws.on('message', (data) => {
      try {
        const input = data.toString();
        shell.stdin.write(input);
      } catch (error: any) {
        console.error('Error writing to shell:', error);
        ws.send(JSON.stringify({ 
          type: 'error', 
          data: `Error: ${error.message}\r\n`
        }));
      }
    });

    ws.on('close', () => {
      console.log('Terminal WebSocket disconnected');
      shell.kill();
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
      shell.kill();
    });
  });

  // File system routes
  app.get('/api/files', async (req, res) => {
    try {
      const files = await buildFileTree(WORKSPACE_ROOT, '', 0);
      res.json(files);
    } catch (error: any) {
      console.error('Error reading files:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/files/read', async (req, res) => {
    try {
      const { path: filePath } = req.query;
      if (!filePath || typeof filePath !== 'string') {
        return res.status(400).json({ error: 'File path is required' });
      }

      const fullPath = resolveSafePath(filePath);
      if (!fullPath) {
        return res.status(403).json({ error: 'Access denied: invalid path' });
      }

      const content = await fs.readFile(fullPath, 'utf-8');
      const extension = path.extname(filePath).slice(1);
      
      res.json({ 
        path: filePath,
        content,
        language: getLanguageFromExtension(extension)
      });
    } catch (error: any) {
      console.error('Error reading file:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/files/write', async (req, res) => {
    try {
      const { path: filePath, content } = req.body;
      if (!filePath || typeof filePath !== 'string') {
        return res.status(400).json({ error: 'File path is required' });
      }

      const fullPath = resolveSafePath(filePath);
      if (!fullPath) {
        return res.status(403).json({ error: 'Access denied: invalid path' });
      }

      await fs.writeFile(fullPath, content || '', 'utf-8');
      res.json({ success: true, path: filePath });
    } catch (error: any) {
      console.error('Error writing file:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/files/create', async (req, res) => {
    try {
      const { path: filePath, type } = req.body;
      if (!filePath || typeof filePath !== 'string') {
        return res.status(400).json({ error: 'File path is required' });
      }

      const fullPath = resolveSafePath(filePath);
      if (!fullPath) {
        return res.status(403).json({ error: 'Access denied: invalid path' });
      }

      if (type === 'directory') {
        await fs.mkdir(fullPath, { recursive: true });
      } else {
        await fs.writeFile(fullPath, '', 'utf-8');
      }

      res.json({ success: true, path: filePath });
    } catch (error: any) {
      console.error('Error creating file/folder:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.delete('/api/files/delete', async (req, res) => {
    try {
      const { path: filePath } = req.query;
      if (!filePath || typeof filePath !== 'string') {
        return res.status(400).json({ error: 'File path is required' });
      }

      const fullPath = resolveSafePath(filePath);
      if (!fullPath) {
        return res.status(403).json({ error: 'Access denied: invalid path' });
      }

      if (fullPath === WORKSPACE_ROOT) {
        return res.status(403).json({ error: 'Cannot delete workspace root' });
      }

      const stats = await fs.stat(fullPath);
      if (stats.isDirectory()) {
        await fs.rm(fullPath, { recursive: true });
      } else {
        await fs.unlink(fullPath);
      }

      res.json({ success: true, path: filePath });
    } catch (error: any) {
      console.error('Error deleting file:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/files/upload', upload.single('file'), async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
      }

      const { destination } = req.body;
      const destPath = resolveSafePath(path.join(destination || '', req.file.originalname));
      
      if (!destPath) {
        return res.status(403).json({ error: 'Access denied: invalid destination' });
      }

      await fs.rename(req.file.path, destPath);
      res.json({ success: true, path: destination });
    } catch (error: any) {
      console.error('Error uploading file:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // GitHub routes
  app.get('/api/github/repos', async (req, res) => {
    try {
      const github = await getUncachableGitHubClient();
      const { data } = await github.repos.listForAuthenticatedUser({
        sort: 'updated',
        per_page: 50,
      });

      res.json(data);
    } catch (error: any) {
      console.error('Error fetching GitHub repos:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/github/repo/:owner/:repo', async (req, res) => {
    try {
      const { owner, repo } = req.params;
      const github = await getUncachableGitHubClient();
      const { data } = await github.repos.get({ owner, repo });

      res.json(data);
    } catch (error: any) {
      console.error('Error fetching GitHub repo:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/github/repo/:owner/:repo/contents', async (req, res) => {
    try {
      const { owner, repo } = req.params;
      const { path: filePath = '' } = req.query;
      const github = await getUncachableGitHubClient();
      
      const { data } = await github.repos.getContent({ 
        owner, 
        repo,
        path: filePath as string
      });

      res.json(data);
    } catch (error: any) {
      console.error('Error fetching repo contents:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/github/clone', async (req, res) => {
    try {
      const { url, directory } = req.body;
      if (!url || typeof url !== 'string') {
        return res.status(400).json({ error: 'Repository URL is required' });
      }

      const urlPattern = /^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/;
      if (!urlPattern.test(url)) {
        return res.status(400).json({ error: 'Invalid GitHub repository URL' });
      }

      const targetDir = resolveSafePath(directory || 'cloned-repos');
      if (!targetDir) {
        return res.status(403).json({ error: 'Access denied: invalid directory' });
      }

      await fs.mkdir(targetDir, { recursive: true });

      const gitProcess = spawn('git', ['clone', url], {
        cwd: targetDir,
        timeout: 60000,
      });

      let stdout = '';
      let stderr = '';

      gitProcess.stdout.on('data', (data: Buffer) => {
        stdout += data.toString();
      });

      gitProcess.stderr.on('data', (data: Buffer) => {
        stderr += data.toString();
      });

      gitProcess.on('close', (code: number) => {
        if (code === 0) {
          res.json({ 
            success: true, 
            message: stdout || stderr,
            directory: targetDir
          });
        } else {
          res.status(500).json({ error: stderr || 'Git clone failed' });
        }
      });

      gitProcess.on('error', (error: any) => {
        res.status(500).json({ error: error.message });
      });
    } catch (error: any) {
      console.error('Error cloning repository:', error);
      res.status(500).json({ error: error.message });
    }
  });

  return httpServer;
}

// Helper functions
async function buildFileTree(dir: string, relativePath: string = '', depth: number = 0): Promise<any[]> {
  if (depth > MAX_DEPTH) {
    return [];
  }

  const items = await fs.readdir(dir);
  const tree = [];

  const ignoredDirs = ['node_modules', '.git', 'dist', 'build', '.next', '.vscode', '.replit', 'tmp', 'attached_assets'];

  for (const item of items) {
    if (ignoredDirs.includes(item) || item.startsWith('.')) {
      continue;
    }

    const fullPath = path.join(dir, item);
    const itemRelativePath = relativePath ? `${relativePath}/${item}` : item;
    
    if (!isPathSafe(fullPath, WORKSPACE_ROOT)) {
      continue;
    }

    try {
      const stats = await fs.stat(fullPath);

      if (stats.isDirectory()) {
        const children = await buildFileTree(fullPath, itemRelativePath, depth + 1);
        tree.push({
          name: item,
          path: itemRelativePath,
          type: 'directory',
          children: children.length > 0 ? children : undefined,
        });
      } else if (stats.isFile()) {
        tree.push({
          name: item,
          path: itemRelativePath,
          type: 'file',
          size: stats.size,
          modified: stats.mtime.toISOString(),
        });
      }
    } catch (error) {
      continue;
    }
  }

  return tree.sort((a, b) => {
    if (a.type === b.type) return a.name.localeCompare(b.name);
    return a.type === 'directory' ? -1 : 1;
  });
}

function resolveSafePath(userPath: string): string | null {
  try {
    const normalizedPath = path.normalize(userPath).replace(/^(\.\.(\/|\\|$))+/, '');
    const fullPath = path.join(WORKSPACE_ROOT, normalizedPath);
    const resolvedPath = path.resolve(fullPath);
    
    if (!resolvedPath.startsWith(WORKSPACE_ROOT)) {
      console.error('Path traversal attempt:', userPath, '->', resolvedPath);
      return null;
    }
    
    return resolvedPath;
  } catch (error) {
    console.error('Path resolution error:', error);
    return null;
  }
}

function isPathSafe(fullPath: string, basePath: string): boolean {
  try {
    const resolvedPath = path.resolve(fullPath);
    return resolvedPath.startsWith(basePath);
  } catch (error) {
    return false;
  }
}

function getLanguageFromExtension(ext: string): string {
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
  return languageMap[ext] || 'plaintext';
}
