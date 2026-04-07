# v4.0 Electron 데스크탑 앱 전환

## 목표

현재 구조:
  브라우저 → localhost:9000 (FastAPI) → data/ 파일

전환 후 구조:
  Electron 앱 실행
    → FastAPI 서버를 내부 프로세스로 자동 시작 (PyInstaller로 단일 실행파일 패키징)
    → Electron 렌더러가 기존 index.html + JSX 로드
    → 브라우저 없이 독립 실행

---

## 현재 프로젝트 구조 파악

작업 시작 전 다음을 확인하고 나에게 보고해:

```
1. package.json 존재 여부 (Node.js 설정)
2. requirements.txt 내용 (Python 패키지 목록)
3. main.py 진입점 확인 (uvicorn 실행 방식)
4. index.html 위치 (static/ 또는 루트)
5. ui/*.jsx 파일 서빙 방식 (StaticFiles 경로)
6. data/ 디렉토리 위치
7. Node.js / npm 설치 여부: node --version && npm --version
8. Python 버전: python --version
```

보고 후 진행해.

---

## Phase 1 — Electron 기반 구조 생성

### 1-1. package.json 생성 (없으면 신규, 있으면 병합)

```json
{
  "name": "oral-record-agent",
  "version": "4.0.0",
  "description": "구술기록 지식그래프 에이전트 v4.0",
  "main": "electron/main.js",
  "scripts": {
    "start": "electron .",
    "dev": "electron . --dev",
    "build:server": "pyinstaller server.spec --noconfirm",
    "build:app": "electron-builder",
    "build": "npm run build:server && npm run build:app"
  },
  "devDependencies": {
    "electron": "^28.0.0",
    "electron-builder": "^24.0.0"
  }
}
```

### 1-2. npm 패키지 설치

```bash
npm install
```

### 1-3. electron/ 디렉토리 생성

```
electron/
├── main.js        ← Electron 메인 프로세스
└── preload.js     ← 렌더러 보안 브릿지
```

### 1-4. electron/main.js 작성

```javascript
const { app, BrowserWindow, dialog, ipcMain } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const net = require('net');
const fs = require('fs');

// 개발 모드 여부
const isDev = process.argv.includes('--dev');

// FastAPI 서버 프로세스 참조
let serverProcess = null;
let mainWindow = null;
let serverPort = 9000;

// ── 포트 사용 가능 여부 확인 ──────────────────────────────
function findAvailablePort(startPort) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.listen(startPort, () => {
      const port = server.address().port;
      server.close(() => resolve(port));
    });
    server.on('error', () => resolve(findAvailablePort(startPort + 1)));
  });
}

// ── FastAPI 서버 실행 경로 결정 ───────────────────────────
function getServerExecutable() {
  if (isDev) {
    // 개발 모드: Python으로 직접 실행
    return { cmd: 'python', args: ['-m', 'uvicorn', 'main:app', '--port', String(serverPort)] };
  }
  // 패키징 모드: PyInstaller 실행파일
  const execName = process.platform === 'win32' ? 'server.exe' : 'server';
  const execPath = path.join(process.resourcesPath, 'server', execName);
  return { cmd: execPath, args: ['--port', String(serverPort)] };
}

// ── FastAPI 서버 시작 ─────────────────────────────────────
function startServer(port) {
  serverPort = port;
  const { cmd, args } = getServerExecutable();

  // 앱 데이터 디렉토리 (패키징 후 data/ 위치)
  const userDataPath = app.getPath('userData');
  const dataPath = isDev
    ? path.join(__dirname, '..', 'data')
    : path.join(userDataPath, 'data');

  // data/ 디렉토리 없으면 생성
  if (!fs.existsSync(dataPath)) {
    fs.mkdirSync(dataPath, { recursive: true });
  }

  const env = {
    ...process.env,
    PORT: String(port),
    DATA_DIR: dataPath,
    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || '',
  };

  serverProcess = spawn(cmd, args, {
    cwd: isDev ? path.join(__dirname, '..') : process.resourcesPath,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  serverProcess.stdout.on('data', (data) => {
    console.log('[Server]', data.toString());
  });

  serverProcess.stderr.on('data', (data) => {
    console.error('[Server Error]', data.toString());
  });

  serverProcess.on('close', (code) => {
    console.log('[Server] 종료 코드:', code);
  });
}

// ── 서버 준비 대기 ────────────────────────────────────────
function waitForServer(port, maxAttempts = 30) {
  return new Promise((resolve, reject) => {
    let attempts = 0;
    const check = () => {
      const client = net.createConnection({ port, host: '127.0.0.1' });
      client.on('connect', () => {
        client.destroy();
        resolve();
      });
      client.on('error', () => {
        client.destroy();
        attempts++;
        if (attempts >= maxAttempts) {
          reject(new Error(`서버가 ${maxAttempts}초 내에 시작되지 않았습니다.`));
        } else {
          setTimeout(check, 1000);
        }
      });
    };
    setTimeout(check, 500);
  });
}

// ── 메인 윈도우 생성 ──────────────────────────────────────
function createWindow(port) {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    title: '구술기록 지식그래프 v4.0',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    show: false,
  });

  // 기존 index.html 을 FastAPI 정적 서빙 통해 로드
  mainWindow.loadURL(`http://127.0.0.1:${port}`);

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    if (isDev) mainWindow.webContents.openDevTools();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ── API 키 설정 IPC ──────────────────────────────────────
ipcMain.handle('set-api-key', (event, key) => {
  process.env.ANTHROPIC_API_KEY = key;
  // 서버 프로세스에는 재시작 필요 — 간단히 알림만
  return { success: true };
});

ipcMain.handle('get-api-key', () => {
  return process.env.ANTHROPIC_API_KEY || '';
});

// ── 앱 시작 ──────────────────────────────────────────────
app.whenReady().then(async () => {
  try {
    // 1. 사용 가능한 포트 탐색
    const port = await findAvailablePort(9000);
    console.log(`[App] 포트 ${port} 사용`);

    // 2. FastAPI 서버 시작
    startServer(port);

    // 3. 서버 준비 대기
    console.log('[App] 서버 시작 대기 중...');
    await waitForServer(port);
    console.log('[App] 서버 준비 완료');

    // 4. 윈도우 생성
    createWindow(port);

  } catch (err) {
    console.error('[App] 시작 오류:', err);
    dialog.showErrorBox('시작 오류', err.message);
    app.quit();
  }
});

app.on('window-all-closed', () => {
  // FastAPI 서버 종료
  if (serverProcess) {
    serverProcess.kill();
    serverProcess = null;
  }
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (mainWindow === null) createWindow(serverPort);
});

app.on('before-quit', () => {
  if (serverProcess) {
    serverProcess.kill();
  }
});
```

### 1-5. electron/preload.js 작성

```javascript
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  setApiKey: (key) => ipcRenderer.invoke('set-api-key', key),
  getApiKey: () => ipcRenderer.invoke('get-api-key'),
  isElectron: true,
});
```

---

## Phase 2 — FastAPI 서버 수정 (포트 환경변수 대응)

### 2-1. main.py 수정

기존 main.py 를 열어서 포트를 환경변수에서 읽도록 수정:

```python
import os
import uvicorn

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 9000))
    data_dir = os.environ.get("DATA_DIR", "data")
    uvicorn.run("main:app", host="127.0.0.1", port=port, reload=False)
```

### 2-2. data/ 경로 동적 처리

graph_db.py 와 ontology_store.py 에서 data/ 경로를 환경변수로 받도록 수정:

```python
import os

# 기존: DATA_DIR = "data"
# 수정:
DATA_DIR = os.environ.get("DATA_DIR", "data")

# 이하 모든 경로를 DATA_DIR 기준으로 변경
GRAPH_FILE = os.path.join(DATA_DIR, "triples", "graph.json")
DRAFTS_DIR = os.path.join(DATA_DIR, "ontologies", "drafts")
CONFIRMED_DIR = os.path.join(DATA_DIR, "ontologies", "confirmed")
```

---

## Phase 3 — API 키 설정 화면 추가

앱 실행 후 ANTHROPIC_API_KEY 가 없으면 설정 화면이 먼저 뜨도록.

### 3-1. index.html 에 API 키 설정 모달 추가

```html
<!-- 네비게이션 우측에 설정 버튼 추가 -->
<button class="nav-tab" onclick="openSettings()" style="margin-left:auto">
  ⚙ 설정
</button>

<!-- API 키 설정 모달 -->
<div id="settings-modal" style="display:none; position:fixed; inset:0;
     background:rgba(0,0,0,0.7); z-index:1000; align-items:center; justify-content:center;">
  <div style="background:#1e293b; padding:32px; border-radius:12px;
              width:480px; border:1px solid #334155;">
    <h2 style="color:#f8fafc; margin-bottom:16px; font-size:16px;">
      Anthropic API 키 설정
    </h2>
    <input id="api-key-input" type="password"
           placeholder="sk-ant-..."
           style="width:100%; padding:10px; margin-bottom:16px;
                  background:#0f172a; border:1px solid #475569;
                  border-radius:6px; color:#f8fafc; font-size:14px;" />
    <div style="display:flex; gap:8px; justify-content:flex-end;">
      <button onclick="closeSettings()"
              style="padding:8px 16px; background:transparent;
                     border:1px solid #475569; border-radius:6px;
                     color:#94a3b8; cursor:pointer;">취소</button>
      <button onclick="saveApiKey()"
              style="padding:8px 16px; background:#3b82f6;
                     border:none; border-radius:6px;
                     color:#fff; cursor:pointer;">저장</button>
    </div>
  </div>
</div>

<script>
async function openSettings() {
  const modal = document.getElementById('settings-modal');
  modal.style.display = 'flex';
  if (window.electronAPI) {
    const key = await window.electronAPI.getApiKey();
    document.getElementById('api-key-input').value = key || '';
  }
}
function closeSettings() {
  document.getElementById('settings-modal').style.display = 'none';
}
async function saveApiKey() {
  const key = document.getElementById('api-key-input').value.trim();
  if (window.electronAPI) {
    await window.electronAPI.setApiKey(key);
  }
  closeSettings();
  alert('API 키가 저장됐습니다. 변경사항은 앱 재시작 후 완전히 적용됩니다.');
}
// 앱 시작 시 API 키 없으면 자동으로 설정 모달 표시
window.addEventListener('load', async () => {
  if (window.electronAPI) {
    const key = await window.electronAPI.getApiKey();
    if (!key) setTimeout(openSettings, 1500);
  }
});
</script>
```

---

## Phase 4 — 개발 모드 실행 테스트

### 4-1. 의존성 확인

```bash
npm install
python -m pip install pyinstaller --break-system-packages
```

### 4-2. 개발 모드 실행

```bash
# 터미널 1: FastAPI 서버는 Electron이 자동 시작하므로 별도 실행 불필요
npm run dev
# 또는
npx electron . --dev
```

### 4-3. 정상 동작 확인 항목

```
□ Electron 윈도우가 열리는가
□ 기존 UI (온톨로지 관리 / 트리플 관리 / 지식그래프 탭) 정상 표시
□ 설정(⚙) 버튼 클릭 → API 키 입력 모달 표시
□ API 키 저장 후 AI 생성 기능 동작
□ 앱 종료 시 서버 프로세스도 함께 종료 (작업 관리자 확인)
```

---

## Phase 5 — PyInstaller 서버 패키징 설정

### 5-1. server.spec 파일 생성 (프로젝트 루트)

```python
# server.spec
import sys
import os
from PyInstaller.utils.hooks import collect_all

block_cipher = None

# 필요한 패키지 수집
datas = [('data', 'data')]
binaries = []
hiddenimports = [
    'uvicorn.logging',
    'uvicorn.loops',
    'uvicorn.loops.auto',
    'uvicorn.protocols',
    'uvicorn.protocols.http',
    'uvicorn.protocols.http.auto',
    'uvicorn.lifespan',
    'uvicorn.lifespan.on',
    'fastapi',
    'anthropic',
]

a = Analysis(
    ['main.py'],
    pathex=['.'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz, a.scripts, [],
    exclude_binaries=True,
    name='server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
)

coll = COLLECT(
    exe, a.binaries, a.zipfiles, a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='server',
)
```

### 5-2. electron-builder 설정 추가 (package.json 에 병합)

```json
{
  "build": {
    "appId": "kr.ac.oral-record-agent",
    "productName": "구술기록 지식그래프",
    "directories": {
      "output": "dist"
    },
    "files": [
      "electron/**/*",
      "static/**/*",
      "ui/**/*",
      "index.html"
    ],
    "extraResources": [
      {
        "from": "dist/server",
        "to": "server",
        "filter": ["**/*"]
      }
    ],
    "win": {
      "target": "nsis",
      "icon": "assets/icon.ico"
    },
    "nsis": {
      "oneClick": false,
      "allowToChangeInstallationDirectory": true,
      "installerLanguages": ["Korean"],
      "language": "1042"
    }
  }
}
```

---

## Phase 6 — .gitignore 및 정리

```
# 기존 .gitignore 에 추가
node_modules/
dist/
build/
*.spec (PyInstaller 빌드 결과)
__pycache__/
*.pyc
.env
data/triples/graph.json
```

---

## 완료 기준

```
Phase 4 개발 모드:
  □ npm run dev → Electron 윈도우 정상 오픈
  □ 기존 기능 전체 동작 확인 (온톨로지/트리플/그래프)
  □ ⚙ 설정에서 API 키 입력 가능
  □ AI 생성 기능 동작
  □ 앱 종료 시 Python 서버 프로세스 함께 종료

Phase 5 패키징 (개발 모드 완료 후 진행):
  □ npm run build:server → dist/server/ 생성
  □ npm run build:app → dist/*.exe 생성
  □ 설치 후 독립 실행 (Python/Node 없이)
```

---

## 제약 조건

```
- 기존 백엔드 파일 (main.py, ontology/, graph/, pipeline/) 최소 수정
  → 포트/경로 환경변수 대응만 추가
- 기존 UI 파일 (ui/*.jsx, index.html) 최소 수정
  → API 키 모달 + electronAPI 체크 코드만 추가
- Electron 관련 파일은 electron/ 디렉토리에 격리
- Phase 4 개발 모드 완료 확인 후 Phase 5 패키징 진행
  → 개발 모드 동작 전에 패키징 시도 금지

Phase 4 완료 후 나에게 보고하면
Phase 5 패키징 진행 여부를 내가 결정한다.
```
