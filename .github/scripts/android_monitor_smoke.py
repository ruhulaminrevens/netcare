"""Exercise the signed app through Android's accessibility hierarchy."""
import subprocess
import time
import re
import xml.etree.ElementTree as ET

def adb(*args):
    return subprocess.check_output(["adb", *args], text=True)

def locate(label, tap=False, attempts=12):
    observed = []
    for _ in range(attempts):
        try:
            adb("shell", "uiautomator", "dump", "/sdcard/netcare-screen.xml")
            root = ET.fromstring(adb("exec-out", "cat", "/sdcard/netcare-screen.xml"))
        except (ET.ParseError, subprocess.CalledProcessError):
            time.sleep(1)
            continue
        observed = []
        for node in root.iter("node"):
            names = [node.get("text",""),node.get("content-desc","")]
            observed.extend(s for s in names if s)
            if not any(label in name.splitlines() for name in names):
                continue
            if tap:
                x,y,right,bottom = map(int,re.findall(r"\d+",node.get("bounds")))
                adb("shell","input","tap",str((x+right)//2),str((y+bottom)//2))
                time.sleep(1)
            return
        time.sleep(1)
    print(adb("logcat","-b","crash","-d","-t","120"),flush=True)
    print(adb("logcat","-d","-s","flutter:E","AndroidRuntime:E")[-3500:],flush=True)
    raise RuntimeError(f"Missing {label!r}; screen labels: {observed!r}")

app = "com.ruhulaminrevens.ruhul_netcare"
print(adb("shell","am","start","-W","-n",app+"/.MainActivity"),flush=True)
locate("EN",tap=True)
locate("Monitor",tap=True)
locate("Open Usage Access")
adb("shell","appops","set",app,"GET_USAGE_STATS","allow")
adb("shell","am","force-stop",app)
print(adb("shell","am","start","-W","-n",app+"/.MainActivity"),flush=True)
locate("Monitor",tap=True)
locate("Day-wise",tap=True)
locate("Usage stats",tap=True)
locate("Data plan",tap=True)
locate("Save limit")
locate("Data plan",tap=True)
locate("Wi-Fi & network",tap=True)
locate("Connection")
locate("Wi-Fi & network",tap=True)
locate("App activity",tap=True)
locate("App activity")
adb("shell","appops","set",app,"SYSTEM_ALERT_WINDOW","allow")
adb("shell","am","force-stop",app)
print(adb("shell","am","start","-W","-n",app+"/.MainActivity"),flush=True)
locate("Monitor",tap=True)
locate("Usage stats",tap=True)
locate("Mini meter",tap=True)
locate("Floating speed meter",tap=True)
services = adb("shell","dumpsys","activity","services",app)
if ".MeterService" not in services or "isForeground=true" not in services:
    raise RuntimeError("Foreground meter service did not start")
print("PASS: signed APK upgrade, monitor pages, usage permission flow and floating service")
