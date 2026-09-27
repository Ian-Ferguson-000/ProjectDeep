"""Run campaign regressions with per-test timeouts and error-log detection."""
import argparse
from pathlib import Path
import subprocess
import sys

p=argparse.ArgumentParser()
p.add_argument('--godot',required=True)
p.add_argument('tests',nargs='*',default=['hearth_campaign','tavern_cycle','party_runtime','recruitment_generations','merchant_economy','combat_stats','class_system','multi_save','autosave_policy','tutorial_sequence','campaign_loop','tavern_activity','consumables_and_targeting','secret_dungeons'])
args=p.parse_args()
root=Path(__file__).resolve().parents[1]
failed=[]
for test in args.tests:
    try:
        run=subprocess.run([args.godot,'--headless','--path',str(root),'--script',f'tests/{test}_test.gd'],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output=run.stdout+run.stderr
        ok=run.returncode==0 and 'ERROR:' not in output
    except subprocess.TimeoutExpired as error:
        output='TIMEOUT\n'+str(error.stdout or '')+str(error.stderr or '')
        ok=False
    (root/f'build/hearth_check_{test}.log').write_text(output,encoding='utf-8')
    print(f'{test}: {"PASS" if ok else "FAIL"}',flush=True)
    if not ok:
        failed.append(test)
        print(output[-2200:],flush=True)
print(f'{len(args.tests)-len(failed)}/{len(args.tests)} passed',flush=True)
sys.exit(bool(failed))
