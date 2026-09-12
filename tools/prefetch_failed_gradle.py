"""Fill Gradle's content-addressed cache from official URLs in a failed build log.
Useful when the JVM resolver fails while Windows curl can reach the repository.
No repository substitution or TLS bypass; optional published SHA-1 is verified.
"""
import concurrent.futures, hashlib, pathlib, re, subprocess, tempfile, urllib.parse
root=pathlib.Path(__file__).resolve().parents[1]
log=(root/'build-android.log').read_text(encoding='utf-8',errors='replace')
urls=sorted(set(re.findall(r"https://[^\s']+\.jar",log)))
cache=pathlib.Path.home()/'.gradle/caches/modules-2/files-2.1'
def fetch(url):
    parsed=urllib.parse.urlparse(url)
    if parsed.hostname not in ('dl.google.com','repo.maven.apache.org'):return 'Skipped nonstandard host'
    relative=parsed.path.split('/maven2/',1)[1]
    parts=relative.split('/')
    if len(parts)<4 or any(p in ('','..','.') for p in parts):return 'Invalid artifact path'
    artifact,version,filename=parts[-3:];group='.'.join(parts[:-3])
    with tempfile.TemporaryDirectory(prefix='focus-gradle-') as temp:
        target=pathlib.Path(temp)/filename
        subprocess.run(['curl.exe','-fsSL','--retry','2','--max-time','120',url,'-o',str(target)],check=True)
        digest=hashlib.sha1(target.read_bytes()).hexdigest()
        check=subprocess.run(['curl.exe','-fsSL','--max-time','20',url+'.sha1'],capture_output=True,text=True)
        if check.returncode==0 and re.match(r'^[0-9a-fA-F]{40}',check.stdout.strip()):
            if check.stdout.strip()[:40].lower()!=digest:raise ValueError('Artifact checksum mismatch')
        folder=cache/group/artifact/version/digest
        folder.mkdir(parents=True,exist_ok=True)
        destination=folder/filename
        if not destination.exists():destination.write_bytes(target.read_bytes())
        return f'Cached {artifact}:{version}'
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as workers:
    for result in workers.map(fetch,urls):print(result,flush=True)
