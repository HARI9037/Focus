"""SDK-independent checks of shipped schema and Android XML. Not a Dart compiler."""
import pathlib,re,sqlite3,xml.etree.ElementTree as ET
root=pathlib.Path(__file__).resolve().parents[1]
text=(root/'lib/core/database/database.dart').read_text()
block=text.split('static const schema = <String>[')[1].split('];')[0]
statements=[]
pattern=r'"""(.*?)"""|\x27([^\x27\n]*)\x27'
for triple,single in re.findall(pattern,block,re.S): statements.append(triple or single)
db=sqlite3.connect(':memory:')
for sql in statements:db.execute(sql)
assert len(statements)==9,len(statements)
assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
try:
 db.execute("INSERT INTO usage_daily VALUES ('2026-09-08','test','Test',-1,'now','estimate')")
 raise AssertionError('Negative usage accepted')
except sqlite3.IntegrityError:pass
db.execute("INSERT INTO usage_daily VALUES ('2026-09-08','test','Test',100,'now','estimate')")
try:
 db.execute("INSERT INTO usage_daily VALUES ('2026-09-08','test','Test',100,'now','estimate')")
 raise AssertionError('Duplicate day accepted')
except sqlite3.IntegrityError:pass
xmls=list((root/'native').rglob('*.xml'))
for file in xmls:ET.parse(file)
manifest=(root/'native/android/app/src/main/AndroidManifest.xml').read_text()
for forbidden in ['android.permission.QUERY_ALL_PACKAGES','android.permission.CALL_PHONE','android.permission.SYSTEM_ALERT_WINDOW']:
 assert forbidden not in manifest,forbidden
service=(root/'native/android/app/src/main/res/xml/focus_accessibility.xml').read_text()
assert 'android:canRetrieveWindowContent="false"' in service
assert 'android:isAccessibilityTool="false"' in service
print(f'PASS: {len(statements)} actual SQL statements, integrity and constraints; {len(xmls)} XML files; permission assertions')
