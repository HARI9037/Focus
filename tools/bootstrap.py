"""Generate official Flutter runners, then apply the reviewed native integration.
Requires Flutter >=3.35 and Python >=3.9. No handwritten Windows runner substitute.
Existing runner folders are not overwritten without --refresh-runners.
"""
import argparse, pathlib, shutil, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--refresh-runners',action='store_true')
args=parser.parse_args()
flutter=shutil.which('flutter')
if not flutter: raise SystemExit('Install Flutter and add flutter/bin to PATH, then run this script again.')
if (root/'android').exists() or (root/'windows').exists():
    if not args.refresh_runners: raise SystemExit('Runners already exist. Run flutter pub get, or back up custom runner changes before --refresh-runners.')
with tempfile.TemporaryDirectory(prefix='focus-runners-') as tmp:
    stage=pathlib.Path(tmp)/'focus'
    subprocess.run([flutter,'create','--project-name','focus','--org','com.personal',
        '--platforms','android,windows','--android-language','kotlin','--no-pub',str(stage)],check=True)
    for folder in ['android','windows']:
        shutil.copytree(stage/folder,root/folder,dirs_exist_ok=True)
    if (stage/'.metadata').exists(): shutil.copy2(stage/'.metadata',root/'.metadata')
shutil.copytree(root/'native'/'android',root/'android',dirs_exist_ok=True)
subprocess.run([flutter,'pub','get'],cwd=root,check=True)
print('Runners created. Run flutter analyze and flutter test before building.')
