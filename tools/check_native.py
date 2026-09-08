"""Compile and run the actual platform-independent Java source used by Android."""
import pathlib, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
source=root/'native/android/app/src/main/java/com/personal/focus'
with tempfile.TemporaryDirectory(prefix='focus-native-tests-') as output:
    subprocess.run(['java','-m','jdk.compiler/com.sun.tools.javac.Main','-d',output,str(source/'NightPolicy.java'),str(source/'UsageAccumulator.java'),str(root/'test/NativePolicyTest.java')],check=True)
    subprocess.run(['java','-cp',output,'NativePolicyTest'],check=True)
