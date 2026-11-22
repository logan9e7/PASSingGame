"""Real four-process ENet loopback test; no mock transport or client positions."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent.parent
out = root / 'artifacts'
out.mkdir(exist_ok=True)
port = 24681
processes = []
logs = []
try:
    for role, name in [('host', 'Host'), ('client', 'Bee'), ('client', 'Cee'), ('client', 'Dee')]:
        report = out / f'network-{name}.json'
        report.unlink(missing_ok=True)
        log = open(out / f'network-{name}.log', 'w')
        logs.append(log)
        args = [os.environ.get('GODOT_BIN', 'godot'), '--headless', '--path', str(root),
                '--script', 'tests/network_probe.gd', '--', f'--role={role}', f'--name={name}',
                f'--port={port}', f'--report={report}']
        processes.append((name, report, subprocess.Popen(args, stdout=log, stderr=log)))
        if role == 'host':
            time.sleep(0.7)
    failed = []
    for name, report, process in processes:
        result = process.wait(timeout=28)
        data = json.loads(report.read_text()) if report.exists() else {'passed': False, 'message': 'Missing report'}
        print(name, data)
        log_text = (out / f'network-{name}.log').read_text()
        errors = [line for line in log_text.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR:' in line]
        if errors:
            print(name, 'Engine errors:', errors[:3])
        if result or not data['passed'] or errors:
            failed.append(name)
    if failed:
        raise SystemExit('Network test failed: ' + ', '.join(failed))
finally:
    for _, _, process in processes:
        if process.poll() is None:
            process.terminate()
    for log in logs:
        log.close()
