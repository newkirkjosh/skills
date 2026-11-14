import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

here = Path(sys.argv[1])
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    stub = root / 'gh'
    stub.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
p=Path(os.environ['FIXTURE']); mode=os.environ['CASE']; a=sys.argv[1:]; h='a'*40
if a[:2]==['pr','view']:
 f=p/'count'; n=int(f.read_text())+1 if f.exists() else 1; f.write_text(str(n))
 print(json.dumps({'headRefOid': ('b'*40 if mode=='move' and n>=2 or mode=='terminal-move' and n>=3 else h)})); sys.exit()
if a[:1]!=['api']: print('unexpected mutation',file=sys.stderr); sys.exit(99)
u=a[1]
if mode=='error': print('HTTP 502',file=sys.stderr); sys.exit(1)
if mode=='limit': print('API rate limit exceeded',file=sys.stderr); sys.exit(1)
if mode=='malformed': print('invalid'); sys.exit()
if u=='graphql':
 second=any(x.startswith('cursor=') for x in a)
 if mode=='page-error' and second: sys.exit(1)
 count=101 if mode in ('pages','page-error') else 0
 nodes=[{'id':str(i),'isResolved':False,'comments':{'nodes':[{'databaseId':i+1}]}} for i in (range(100,101) if second else range(min(count,100)))]
 print(json.dumps({'data':{'repository':{'pullRequest':{'reviewThreads':{'totalCount':count,'nodes':nodes,'pageInfo':{'hasNextPage':count>100 and not second,'endCursor':'next'}}}}}})); sys.exit()
rows=[]
if '/check-runs' in u:
 if mode not in ('absent','pages','page-error'):
  rows=[{'id':7,'app':{'id':1,'slug':'coderabbit'},'name':'CodeRabbit','head_sha':'b'*40 if mode=='old' else h,'status':'in_progress' if mode=='pending' else 'completed','conclusion':'skipped' if mode=='paused' else 'success'}]
 data={'total_count':len(rows),'check_runs':rows}
elif '/actions/runs' in u:
 if mode!='no-runs': rows=[{'head_sha':h,'status':'completed','conclusion':'skipped' if mode=='skipped' else 'success'}]
 data={'total_count':len(rows),'workflow_runs':rows}
elif '/reviews?' in u: data=[{'id':1,'body':'Body-only finding','commit_id':h,'user':{'login':'reviewer'},'state':'COMMENTED'}]
elif '/issues/' in u and mode=='comment-limit': data=[{'body':'Rate limit exceeded','user':{'login':'coderabbitai[bot]'}}]
else: data=[]
print(json.dumps(data))
''')
    stub.chmod(0o755)
    def run(case, script='pr-status.sh', rc=0, state=None, extra=None):
        (root / 'count').unlink(missing_ok=True)
        env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'], FIXTURE=str(root), CASE=case, WAIT_INTERVAL='0')
        env.update(extra or {})
        p = subprocess.run(['bash', str(here/script), '12', 'owner/repo', '0'], env=env, text=True, capture_output=True)
        assert p.returncode == rc, (case, script, p.returncode, p.stdout, p.stderr)
        d = json.loads(p.stdout)
        if state:
            assert d['state'] == state, d
        return d
    policy=root/'policy.json'
    policy.write_text(json.dumps(dict(source='fixture repository rules', required_checks=['Missing'], required_reviewers=['configured'], optional_not_configured={'optional':'fixture service confirms disabled'})))
    coverage=run('success',extra={'PR_EVIDENCE_POLICY':str(policy)})['coverage']
    assert coverage['required_reviewers']['configured']=='absent'
    assert coverage['required_checks']['Missing']['state']=='absent'
    assert coverage['optional_not_configured']['optional']
    d=run('pages'); assert len(d['unresolved_threads'])==101
    assert d['unresolved_threads'][-1]['first_comment_id']==101
    assert run('success')['reviews_on_head'][0]['body']=='Body-only finding'
    for case in ('page-error','error','malformed','old'):
        run(case, rc=8, state='READ_ERROR')
    run('move', rc=6, state='HEAD_MOVED')
    run('terminal-move','wait-for-ci.sh',6,'HEAD_MOVED')
    run('success','wait-for-ci.sh',0,'PASS')
    run('skipped','wait-for-ci.sh',1,'FAIL')
    run('no-runs','wait-for-ci.sh',3,'TIMEOUT')
    run('error','wait-for-ci.sh',8,'READ_ERROR')
    run('paused','wait-for-coderabbit.sh',7,'PAUSED')
    run('paused','wait-for-coderabbit.sh',3,'TIMEOUT',{'WAIT_AFTER_RUN':'7'})
    run('pending','wait-for-coderabbit.sh',3,'TIMEOUT')
    run('absent','wait-for-coderabbit.sh',3,'TIMEOUT')
    run('limit','wait-for-coderabbit.sh',5,'READ_ERROR')
    run('comment-limit','wait-for-coderabbit.sh',0,'PASS')
    p=subprocess.run(['bash',str(here/'wait-for-ci.sh'),'12','owner/repo','oops'],capture_output=True)
    assert p.returncode==2
    # Merge authority stays with caller; helper cannot invoke mutation commands.
    text=(here/'pr-evidence.py').read_text()
    assert "'merge'" not in text and "'comment'" not in text
    contract=(here.parent/'references/pr-evidence.md').read_text()
    assert '--match-head-commit <sha>' in contract and 'repository policy grants merge authority' in contract
print('PR evidence offline scenarios passed')

# Deterministic multi-cycle tests exercise real main/collection logic without sleeps.
import contextlib
import copy
import importlib.util
import io
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('evidence', here/'pr-evidence.py')
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)
H = 'a'*40

def sample(workflows=None, checks=None):
    return dict(state='COLLECTED', head=H, workflows=workflows or [], checks=checks or [], issue_comments=[], statuses=[], reviews_on_head=[], reviews_on_older_commits=[])

def workflow(state='completed'):
    return dict(status=state, conclusion='success' if state=='completed' else None)

def check(identifier, conclusion='success', status='completed', app=1):
    return dict(id=identifier, name='CodeRabbit', status=status, conclusion=conclusion, app={'id':app})

def cycles(mode, snapshots, minutes, expected, after=''):
    clock=[0]; seen=[]
    def collect(*args):
        seen.append(clock[0])
        return copy.deepcopy(snapshots[min(len(seen)-1, len(snapshots)-1)])
    def sleep(seconds): clock[0]+=seconds
    out=io.StringIO()
    with patch.object(evidence,'collect',collect), patch.object(evidence,'head',return_value=H), patch.object(evidence,'coverage',return_value={}), patch.object(evidence.time,'monotonic',side_effect=lambda:clock[0]), patch.object(evidence.time,'sleep',sleep), patch.dict(os.environ,{'WAIT_INTERVAL':'30','WAIT_AFTER_RUN':after}), patch.object(sys,'argv',['script',mode,'12','owner/repo',str(minutes)]), contextlib.redirect_stdout(out):
        rc=evidence.main()
    assert rc==expected,(rc,out.getvalue())
    return json.loads(out.getvalue()),seen

result,seen=cycles('ci',[sample(),sample([workflow('in_progress')]),sample([workflow()])],5,0)
assert result['state']=='PASS' and seen==[0,30,60]
result,seen=cycles('ci',[sample()],5,4)
assert result['state']=='NO_RUNS' and seen[-1]==180
result,seen=cycles('ci',[sample([workflow('in_progress')])],1,3)
assert result['state']=='TIMEOUT' and seen==[0,30,60]
result,seen=cycles('coderabbit',[sample(checks=[check(7,'skipped')]),sample(checks=[check(8,None,'in_progress')]),sample(checks=[check(8)])],2,0,'7')
assert result['wait_after_run']=='' and len(seen)==3
result,seen=cycles('coderabbit',[sample(checks=[check(7,'skipped')]),sample(checks=[check(8,'skipped')])],2,7,'7')
assert len(seen)==2 and result['state']=='PAUSED'
result,seen=cycles('coderabbit',[sample(checks=[check(7,'skipped')])],1,3,'7')
assert result['wait_after_run']=='7'

# Real pagination consumes distinct sequential pages, checks counts, and fails closed.
page1=[{'id':i} for i in range(100)]
page2=[{'id':100}]
with patch.object(evidence,'gh',side_effect=[{'check_runs':page1,'total_count':101},{'check_runs':page2,'total_count':101}]) as api:
    assert len(evidence.pages('checks','check_runs'))==101
    assert api.call_args_list[1].args[-1].endswith('page=2')
with patch.object(evidence,'gh',side_effect=[page1,page2]):
    assert len(evidence.pages('statuses'))==101
with patch.object(evidence,'gh',return_value={'check_runs':page2,'total_count':2}):
    try: evidence.pages('checks','check_runs')
    except evidence.ReadError: pass
    else: raise AssertionError('count mismatch accepted')

with tempfile.TemporaryDirectory() as tmp:
    policy=Path(tmp)/'policy.json'
    policy.write_text(json.dumps(dict(source='fixture policy',required_checks=['CodeRabbit'],required_reviewers=['reviewer'])))
    d=sample(checks=[check(1,'failure',app=1),check(2,app=2)])
    d['reviews_on_head']=[dict(id=i,user={'login':'reviewer'},state=state) for i,state in enumerate(['CHANGES_REQUESTED','COMMENTED'])]
    with patch.dict(os.environ,{'PR_EVIDENCE_POLICY':str(policy)}):
        cov=evidence.coverage(d)
        assert cov['required_checks']['CodeRabbit']['state']=='blocked'
        assert len(cov['required_checks']['CodeRabbit']['matches'])==2
        assert cov['required_reviewers']['reviewer']=='CHANGES_REQUESTED'
        d['checks']=[check(2)]
        d['statuses']=[dict(id=3,context='CodeRabbit',state='failure',creator={'login':'service'})]
        assert evidence.coverage(d)['required_checks']['CodeRabbit']['state']=='blocked'
        d['reviews_on_head'].append(dict(id=3,user={'login':'reviewer'},state='APPROVED'))
        assert evidence.coverage(d)['required_reviewers']['reviewer']=='APPROVED'

# Old comments must be older than neither the head nor its last force-push.
d=sample(); d['issue_comments']=[dict(user={'login':'coderabbitai[bot]'},body='Rate limit exceeded',created_at='2025-01-02T00:00:00Z')]
def dates(force='2025-01-03T00:00:00Z', commit='2025-01-01T00:00:00Z'):
    return [{'commit':{'committer':{'date':commit}}},{'data':{'repository':{'pullRequest':{'timelineItems':{'nodes':[{'createdAt':force}]}}}}}]
with patch.object(evidence,'gh',side_effect=dates()):
    assert not evidence.current_rate_limit(d,'12','owner/repo')
with patch.object(evidence,'gh',side_effect=dates('2025-01-01T00:00:00Z')):
    assert evidence.current_rate_limit(d,'12','owner/repo')
with patch.object(evidence,'gh',side_effect=dates('2025-01-01T00:00:00Z','2025-01-03T00:00:00Z')):
    assert not evidence.current_rate_limit(d,'12','owner/repo')
print('Multi-cycle, coverage collision, rate-limit freshness and pagination tests passed')

# Objections survive pushes; older approvals alone never satisfy head coverage.
with tempfile.TemporaryDirectory() as tmp:
    policy=Path(tmp)/'policy.json'
    policy.write_text(json.dumps(dict(source='fixture policy',required_checks=[],required_reviewers=['reviewer'])))
    def review(i,state): return dict(id=i,user={'login':'reviewer'},state=state)
    d=sample()
    d['reviews_on_older_commits']=[review(1,'CHANGES_REQUESTED')]
    d['reviews_on_head']=[review(2,'COMMENTED')]
    with patch.dict(os.environ,{'PR_EVIDENCE_POLICY':str(policy)}):
        assert evidence.coverage(d)['required_reviewers']['reviewer']=='CHANGES_REQUESTED'
        d['reviews_on_head'].append(review(3,'APPROVED'))
        assert evidence.coverage(d)['required_reviewers']['reviewer']=='APPROVED'
        d['reviews_on_head']=[review(2,'COMMENTED')]
        d['reviews_on_older_commits']=[review(1,'DISMISSED')]
        assert evidence.coverage(d)['required_reviewers']['reviewer']=='COMMENTED'
        d['reviews_on_head']=[review(2,'APPROVED')]
        d['reviews_on_older_commits']=[review(3,'CHANGES_REQUESTED')]
        assert evidence.coverage(d)['required_reviewers']['reviewer']=='CHANGES_REQUESTED'
        d['reviews_on_head']=[]
        d['reviews_on_older_commits']=[review(1,'APPROVED')]
        assert evidence.coverage(d)['required_reviewers']['reviewer']=='absent'
d=sample(); d['issue_comments']=[dict(user={'login':'coderabbitai[bot]'},body='Rate limit exceeded',created_at='2025-01-01T00:00:00Z',updated_at='2025-01-04T00:00:00Z')]
with patch.object(evidence,'gh',side_effect=dates()):
    assert evidence.current_rate_limit(d,'12','owner/repo')
result,seen=cycles('ci',[sample()],1,3)
assert result['state']=='TIMEOUT' and seen==[0,30,60]
result,seen=cycles('ci',[sample([workflow('in_progress')]),sample([dict(status='completed',conclusion='failure')])],1,1)
assert result['state']=='FAIL' and seen==[0,30]
print('Cross-commit objections, edited rate limits and short CI deadline regressions passed')
