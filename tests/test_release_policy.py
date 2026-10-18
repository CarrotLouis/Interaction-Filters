"""Release policy, permanent historical withdrawal and reviewed-source refusal.

All CLI refusal tests use a small private project under build/, never modify the
real project policy, never touch the game, and never generate delivery packages.
"""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import unittest
import uuid
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import verify_isolation
from release_policy import read_policy,validate_policy,require_packaging,WITHDRAWN

SOURCE="local BUILD_ID='test-build'"
BASE={'build_id':'test-build','state':'withdrawn','user_live_status':'failed',
      'packaging_allowed':False,'reason':'A live diagnostic still crashed.'}

def private_root(prefix):
    folder=ROOT/'build'/(prefix+uuid.uuid4().hex)
    folder.mkdir(parents=True)
    return folder

class ReleasePolicy(unittest.TestCase):
    def test_explicit_matching_policy(self):
        self.assertEqual(validate_policy(dict(BASE),SOURCE),BASE)
        allowed=dict(BASE,state='candidate',user_live_status='pending',packaging_allowed=True)
        self.assertTrue(validate_policy(allowed,SOURCE)['packaging_allowed'])

    def test_mismatch_missing_invalid_and_failed_cannot_ship(self):
        for changes in [{'build_id':'other'},{'packaging_allowed':'false'},
                        {'packaging_allowed':None},{'state':'unknown'},
                        {'reason':''},{'reason':None},{'user_live_status':'unknown'},
                        {'packaging_allowed':True},
                        {'state':'candidate','packaging_allowed':True}]:
            with self.subTest(changes=changes),self.assertRaises(ValueError):
                validate_policy(dict(BASE,**changes),SOURCE)
        with self.assertRaises(ValueError):validate_policy(BASE,'source without build ID')

    def test_historical_failed_build_cannot_be_relabelled_candidate(self):
        for old in WITHDRAWN:
            policy=dict(BASE,build_id=old,state='candidate',user_live_status='pending',packaging_allowed=True)
            with self.assertRaisesRegex(ValueError,'historically failed'):
                validate_policy(policy,"local BUILD_ID='"+old+"'")

    def test_current_candidate_requires_exact_review(self):
        p=read_policy()
        self.assertEqual(p['build_id'],'0.3.0-cache-primary.1')
        self.assertEqual((p['state'],p['user_live_status']),('candidate','pending'))
        self.assertTrue(require_packaging()['packaging_allowed'])
        original=verify_isolation.verify_review()
        target=private_root('review-refusal-')
        for name in verify_isolation.REVIEWED_FILES:
            at=target/name;at.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/name,at)
        (target/'backend-review.json').write_text(json.dumps(original),encoding='utf-8')
        with patch.object(verify_isolation,'ROOT',target):
            verify_isolation.verify_review()
            (target/'src/cache_backend.lua').write_text('-- changed after review',encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'changed since review'):verify_isolation.verify_review()

    def test_withdrawn_cli_refusal_and_help_have_no_delivery_side_effect(self):
        project=private_root('withdrawn-cli-')
        (project/'scripts').mkdir();(project/'src').mkdir()
        for name in ['build.py','build_mod.py','export_source.py','release_policy.py','assemble.py']:
            shutil.copyfile(ROOT/'scripts'/name,project/'scripts'/name)
        (project/'src/entry.lua').write_text(SOURCE,encoding='utf-8')
        (project/'release-policy.json').write_text(json.dumps(BASE),encoding='utf-8')
        for script in ['build.py','build_mod.py','export_source.py']:
            target=project/('must-not-create-'+uuid.uuid4().hex)
            command=[sys.executable,'-B',str(project/'scripts'/script)]
            result=subprocess.run(command+['--output-dir',str(target)],capture_output=True,text=True)
            self.assertEqual(result.returncode,2,result.stderr)
            self.assertIn('packaging refused',result.stderr)
            self.assertFalse(target.exists(),'withdrawn CLI created a delivery directory')
            result=subprocess.run(command+['--help'],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('usage:',result.stdout)
            self.assertFalse(target.exists())

    def test_direct_packer_refuses_missing_or_stale_full_gate_stamp(self):
        project=private_root('stamp-refusal-')
        for name in verify_isolation.REVIEWED_FILES|{
            'scripts/build_mod.py','scripts/release_policy.py','scripts/verify_isolation.py',
            'scripts/audit_ffi.py','release-policy.json','backend-review.json','build/addon.lua'}:
            at=project/name;at.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/name,at)
        for stamp in [None,{'offline_gates_passed':True,'source_sha256':'0'*64}]:
            if stamp is not None:
                (project/'build/tests-passed.json').write_text(json.dumps(stamp),encoding='utf-8')
            target=project/('no-delivery-'+uuid.uuid4().hex)
            result=subprocess.run([sys.executable,'-B',str(project/'scripts/build_mod.py'),
                '--output-dir',str(target)],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('required offline gates missing/stale',result.stderr)
            self.assertFalse(target.exists())

if __name__=='__main__':unittest.main(verbosity=2)
