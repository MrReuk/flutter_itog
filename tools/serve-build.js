const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const args = process.argv.slice(2);
function opt(name, fallback) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}
const positional = args.filter((a, i) => !a.startsWith('--') && !args[i - 1]?.startsWith('--'));
const root = path.resolve(positional[0] || 'build/web');
let base = opt('--base', '/');
if (!base.startsWith('/')) base = '/' + base;
if (!base.endsWith('/')) base += '/';
const port = Number(opt('--port', '8000'));
const delay = Number(opt('--delay-ms', '0'));

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.symbols': 'text/plain; charset=utf-8',
};
const compressible = new Set(['.html', '.js', '.mjs', '.json', '.wasm', '.css', '.otf', '.ttf', '.symbols']);

function send(req, res, status, file) {
  const ext = path.extname(file).toLowerCase();
  const type = types[ext] || 'application/octet-stream';
  let body = fs.readFileSync(file);
  const headers = { 'Content-Type': type, 'Cache-Control': 'max-age=600' };
  if (compressible.has(ext) && /\bgzip\b/.test(req.headers['accept-encoding'] || '')) {
    body = zlib.gzipSync(body, { level: 6 });
    headers['Content-Encoding'] = 'gzip';
  }
  headers['Content-Length'] = body.length;
  setTimeout(() => {
    res.writeHead(status, headers);
    res.end(req.method === 'HEAD' ? undefined : body);
  }, delay);
}

http
  .createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    let pathname = decodeURIComponent(url.pathname);
    console.log(req.method, pathname);
    if (!pathname.startsWith(base)) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found (вне ' + base + ')');
      return;
    }
    let rel = pathname.slice(base.length);
    if (rel === '' || rel.endsWith('/')) rel += 'index.html';
    const file = path.join(root, rel);
    if (file.startsWith(root) && fs.existsSync(file) && fs.statSync(file).isFile()) {
      send(req, res, 200, file);
      return;
    }
    const fallback = path.join(root, '404.html');
    if (fs.existsSync(fallback)) {
      send(req, res, 404, fallback);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('404: файла нет, и нет 404.html');
    }
  })
  .listen(port, () => {
    console.log(`Раздаю ${root}`);
    console.log(`Адрес: http://localhost:${port}${base}`);
  });
