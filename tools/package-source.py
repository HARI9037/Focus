"""Archive tracked and new source, respecting Git ignores and excluding secrets."""
import pathlib
import subprocess
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
names = subprocess.check_output([
    'git', '-c', f'safe.directory={root.as_posix()}', 'ls-files',
    '--cached', '--others', '--exclude-standard', '-z',
], cwd=root).decode().split('\0')
dist = root / 'dist'
dist.mkdir(exist_ok=True)
output = dist / 'Focus-0.2.0-source.zip'
count = 0
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in sorted(set(names)):
        if not name:
            continue
        path = root / name
        if not path.is_file() or not path.resolve().is_relative_to(root):
            continue
        if path.suffix.lower() in {'.zip', '.jks', '.keystore', '.db', '.log'}:
            continue
        if path.name in {'key.properties', 'local.properties'} or path.name.startswith('.env'):
            continue
        archive.write(path, 'Focus/' + name)
        count += 1
print(f'Archived {count} source files to {output}')
