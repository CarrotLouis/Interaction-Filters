"""Keep the live-failed diagnostic withdrawn despite green offline tests.

Uses pure policy fixtures and read-only CLI refusal/help paths. No game access,
no package export and no recursive temporary-directory cleanup.
"""
from pathlib import Path
import hashlib
import subprocess
import sys
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from release_policy import read_policy,validate_policy,require_packaging

SOURCE="local BUILD_ID='test-build'"
BASE={'build_id':'test-build','state':'withdrawn','user_live_status':'failed',
      'packaging_allowed':False,'reason':'A live diagnostic still crashed.'}

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

    def test_current_build_is_live_failed_and_refused(self):
        policy=read_policy()
        self.assertEqual(policy['state'],'withdrawn')
        self.assertEqual(policy['user_live_status'],'failed')
        self.assertFalse(policy['packaging_allowed'])
        with self.assertRaisesRegex(ValueError,'packaging refused'):require_packaging()

    def test_cli_refusal_and_help_have_no_delivery_side_effect(self):
        before=hashlib.sha256((ROOT/'release-policy.json').read_bytes()).hexdigest()
        for script in ['build.py','build_mod.py','export_source.py']:
            target=ROOT/'build'/('must-not-create-'+uuid.uuid4().hex)
            self.assertFalse(target.exists())
            command=[sys.executable,'-B',str(ROOT/'scripts'/script)]
            result=subprocess.run(command+['--output-dir',str(target)],capture_output=True,text=True)
            self.assertEqual(result.returncode,2,result.stderr)
            self.assertIn('packaging refused',result.stderr)
            self.assertFalse(target.exists(),'withdrawn CLI created a delivery directory')
            help_result=subprocess.run(command+['--help'],capture_output=True,text=True)
            self.assertEqual(help_result.returncode,0,help_result.stderr)
            self.assertIn('usage:',help_result.stdout)
            self.assertFalse(target.exists())
        self.assertEqual(hashlib.sha256((ROOT/'release-policy.json').read_bytes()).hexdigest(),before)

if __name__=='__main__':unittest.main(verbosity=2)
