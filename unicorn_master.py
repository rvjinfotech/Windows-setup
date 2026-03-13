"""
Unicorn Master - Universal Worker Manager
Copy this file to any project and it just works!

ZERO dependencies on your app structure.
Just configure unicorn_config.json and run.
"""

import json
import subprocess
import time
import os
import sys
from pathlib import Path

CONFIG_FILE = "unicorn_config.json"
LOG_DIR = Path("logs")


def main():
    # Load config
    if not Path(CONFIG_FILE).exists():
        print(f"ERROR: {CONFIG_FILE} not found!")
        print("Create it first. See unicorn_config.json example.")
        sys.exit(1)
    
    with open(CONFIG_FILE) as f:
        config = json.load(f)
    
    LOG_DIR.mkdir(exist_ok=True)
    processes = []
    restart_delay = config.get("restart_delay", 5)
    
    print("[UNICORN] Starting workers...")
    
    # Start all workers
    for service in config["services"]:
        if not service.get("enabled", True):
            continue
        
        name = service["name"]
        script = service["script"]
        port = service["port"]
        
        # Setup environment
        env = os.environ.copy()
        env["PORT"] = str(port)
        env["WORKER_ID"] = name
        
        # Prepare command
        cmd = [sys.executable, script]
        log_file = LOG_DIR / f"{name}.log"
        
        print(f"  Starting {name} on port {port}")
        
        # Start process
        with open(log_file, "w") as log:
            proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
        
        processes.append({"name": name, "port": port, "script": script, "process": proc})
    
    print(f"[UNICORN] {len(processes)} workers running. Monitoring...")
    
    # Monitor and restart
    try:
        while True:
            time.sleep(10)
            
            for worker in processes:
                if worker["process"].poll() is not None:
                    print(f"[RESTART] {worker['name']} died! Restarting in {restart_delay}s...")
                    time.sleep(restart_delay)
                    
                    # Restart
                    env = os.environ.copy()
                    env["PORT"] = str(worker["port"])
                    env["WORKER_ID"] = worker["name"]
                    
                    log_file = LOG_DIR / f"{worker['name']}.log"
                    with open(log_file, "a") as log:
                        worker["process"] = subprocess.Popen(
                            [sys.executable, worker["script"]], 
                            env=env, 
                            stdout=log, 
                            stderr=subprocess.STDOUT
                        )
    
    except KeyboardInterrupt:
        print("\n[UNICORN] Stopping...")
        for worker in processes:
            try:
                worker["process"].terminate()
                worker["process"].wait(timeout=5)
            except:
                worker["process"].kill()


if __name__ == "__main__":
    main()