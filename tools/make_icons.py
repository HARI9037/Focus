"""Deterministic Focus mark: an F inside four attention brackets."""
from PIL import Image, ImageDraw
from pathlib import Path
root=Path(__file__).resolve().parents[1]
image=Image.new('RGBA',(1024,1024),'#101510')
draw=ImageDraw.Draw(image)
accent='#b9d98a'
for points in [(200,360,200,200,360,200),(664,200,824,200,824,360),(200,664,200,824,360,824),(664,824,824,824,824,664)]:
    draw.line(list(zip(points[::2],points[1::2])),fill=accent,width=48,joint='curve')
draw.rectangle((382,338,444,688),fill=accent)
draw.rectangle((382,338,657,396),fill=accent)
draw.rectangle((382,482,595,540),fill=accent)
for bucket,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    for base in ['native/android','android']:
        path=root/base/f'app/src/main/res/mipmap-{bucket}/ic_launcher.png'
        path.parent.mkdir(parents=True,exist_ok=True)
        image.resize((size,size),Image.Resampling.LANCZOS).save(path)
image.save(root/'windows/runner/resources/app_icon.ico',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
