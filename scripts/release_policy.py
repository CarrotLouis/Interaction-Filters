"""Packaging policy after the 2026-10-18 entry-only crash.

Offline instruction tests passed while the user's game still exited. A second
green offline run must not silently make the withdrawn build distributable.
Read-only library: no game access, file writes or policy override.
"""
from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parents[1]
WITHDRAWN={'0.2.3-primary-only.1','0.2.4-call-wrapper.1','0.2.5-entry-only.1'}

def validate_policy(policy,source):
    match=re.search(r"local BUILD_ID='([^']+)'",source)
    if not match or policy.get('build_id')!=match[1]:
        raise ValueError('release policy does not match the current source build ID')
    if type(policy.get('packaging_allowed'))is not bool:
        raise ValueError('release policy requires an explicit boolean packaging_allowed')
    if policy.get('state')not in {'candidate','withdrawn'}:
        raise ValueError('unknown release policy state')
    if policy.get('user_live_status')not in {'pending','failed','passed'}:
        raise ValueError('unknown user live status')
    if policy['state']=='withdrawn'and policy['packaging_allowed']:
        raise ValueError('withdrawn builds cannot permit packaging')
    if policy['user_live_status']=='failed'and policy['packaging_allowed']:
        raise ValueError('live-failed builds cannot permit packaging')
    if match[1] in WITHDRAWN and policy['packaging_allowed']:
        raise ValueError('historically failed builds remain withdrawn')
    if not isinstance(policy.get('reason'),str)or not policy['reason'].strip():
        raise ValueError('release policy requires a reason')
    return policy

def read_policy():
    return validate_policy(json.loads((ROOT/'release-policy.json').read_text(encoding='utf-8')),
                           (ROOT/'src/entry.lua').read_text(encoding='utf-8'))

def require_packaging():
    policy=read_policy()
    if not policy['packaging_allowed']:
        raise ValueError('packaging refused: '+policy['build_id']+' is '+policy['state']+'. '+policy['reason'])
    from verify_isolation import verify_review
    verify_review()
    return policy
