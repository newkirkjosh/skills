"""Read-only evidence collector. Ported concepts from the catalog's former
GitHub head-status and wait helpers; pagination/validation deliberately replaced.
JSON parsing and connection traversal use only the Python standard library.
"""
from datetime import datetime
import json
import os
import re
import subprocess
import sys
import time


class ReadError(Exception):
    pass


class WaitTimeout(Exception):
    pass


# A single invocation is synchronous; every gh read shares its overall budget.
request_deadline = None


def gh(*args):
    remaining = None if request_deadline is None else request_deadline - time.monotonic()
    if remaining is not None and remaining <= 0:
        raise WaitTimeout()
    try:
        p = subprocess.run(['gh', *args], text=True, capture_output=True, timeout=60 if remaining is None else min(60, remaining))
    except subprocess.TimeoutExpired:
        if request_deadline is not None and time.monotonic() >= request_deadline:
            raise WaitTimeout()
        raise ReadError('API request timed out')
    if request_deadline is not None and time.monotonic() >= request_deadline:
        raise WaitTimeout()
    if p.returncode:
        raise ReadError(p.stderr.strip() or 'gh failed')
    try:
        value = json.loads(p.stdout)
    except ValueError:
        raise ReadError('malformed JSON')
    if value is None or (isinstance(value, dict) and value.get('errors')):
        raise ReadError('null response or API errors')
    return value


def head(pr, repo):
    h = gh('pr', 'view', pr, '-R', repo, '--json', 'headRefOid')['headRefOid']
    if not isinstance(h, str) or not re.fullmatch('[0-9a-f]{40}', h):
        raise ReadError('invalid head')
    return h


def pages(url, key=None):
    result = []
    page = 1
    seen_pages = set()
    while True:
        data = gh('api', url + ('&' if '?' in url else '?') + f'per_page=100&page={page}')
        rows = data[key] if key else data
        if not isinstance(rows, list) or any(not isinstance(r, dict) for r in rows):
            raise ReadError('malformed page')
        if key and (not isinstance(data.get('total_count'), int) or data['total_count'] < 0):
            raise ReadError('missing total_count')
        signature = json.dumps(rows, sort_keys=True)
        if rows and signature in seen_pages:
            raise ReadError('repeated page')
        seen_pages.add(signature)
        result.extend(rows)
        if len(rows) < 100:
            if key and len(result) != data['total_count']:
                raise ReadError('incomplete collection')
            return result
        page += 1


def threads(pr, repo):
    owner, name = repo.split('/')
    cursor = None
    result = []
    seen = set()
    while True:
        query = '''query($owner:String!,$name:String!,$pr:Int!,$cursor:String){repository(owner:$owner,name:$name){pullRequest(number:$pr){reviewThreads(first:100,after:$cursor){totalCount nodes{id isResolved isOutdated path line comments(first:1){nodes{databaseId}}} pageInfo{hasNextPage endCursor}}}}}'''
        args = ['api', 'graphql', '-f', 'query=' + query, '-f', 'owner=' + owner, '-f', 'name=' + name, '-F', 'pr=' + pr]
        if cursor:
            args += ['-f', 'cursor=' + cursor]
        c = gh(*args)['data']['repository']['pullRequest']['reviewThreads']
        nodes, info = c['nodes'], c['pageInfo']
        if not isinstance(nodes, list) or not isinstance(info['hasNextPage'], bool):
            raise ReadError('malformed thread page')
        for n in nodes:
            if not isinstance(n['isResolved'], bool) or not isinstance(n['id'], str) or n['id'] in seen:
                raise ReadError('invalid/duplicate thread')
            first = n['comments']['nodes']
            if len(first) != 1 or type(first[0]['databaseId']) is not int:
                raise ReadError('missing thread comment mapping')
            n['first_comment_id'] = first[0]['databaseId']
            seen.add(n['id'])
        result.extend(nodes)
        if not info['hasNextPage']:
            if len(result) != c['totalCount']:
                raise ReadError('incomplete threads')
            return result
        nxt = info['endCursor']
        if not isinstance(nxt, str) or not nxt or nxt == cursor or not nodes:
            raise ReadError('invalid thread cursor')
        cursor = nxt


def collect(pr, repo):
    h = head(pr, repo)
    base = 'repos/' + repo
    checks = pages(f'{base}/commits/{h}/check-runs', 'check_runs')
    statuses = pages(f'{base}/commits/{h}/statuses')
    reviews = pages(f'{base}/pulls/{pr}/reviews')
    comments = pages(f'{base}/pulls/{pr}/comments')
    bodies = pages(f'{base}/issues/{pr}/comments')
    runs = pages(f'{base}/actions/runs?head_sha={h}', 'workflow_runs')
    ts = threads(pr, repo)
    for c in checks:
        if c['head_sha'] != h or not isinstance(c['name'], str) or not isinstance(c['status'], str) or 'conclusion' not in c:
            raise ReadError('invalid or stale check')
    for r in runs:
        if r['head_sha'] != h or not isinstance(r['status'], str) or 'conclusion' not in r:
            raise ReadError('invalid or stale workflow')
    for r in reviews:
        if not isinstance(r['body'], str) or not isinstance(r['commit_id'], str) or not isinstance(r['user']['login'], str) or not isinstance(r['state'], str):
            raise ReadError('invalid review')
    for c in comments + bodies:
        if not isinstance(c['body'], str) or not isinstance(c['user']['login'], str):
            raise ReadError('invalid comment')
    for s in statuses:
        if not isinstance(s['context'], str) or s['state'] not in ('pending', 'success', 'failure', 'error'):
            raise ReadError('invalid status')
    if head(pr, repo) != h:
        return {'state': 'HEAD_MOVED', 'head': h}
    return dict(state='COLLECTED', head=h, sources={k: 'complete' for k in ('checks', 'statuses', 'reviews', 'comments', 'issue_comments', 'workflows', 'threads')}, checks=checks, statuses=statuses, reviews_on_head=[r for r in reviews if r['commit_id'] == h], reviews_on_older_commits=[r for r in reviews if r['commit_id'] != h], review_comments=comments, issue_comments=bodies, workflows=runs, unresolved_threads=[t for t in ts if not t['isResolved']], threads=ts, merge_verdict='CALLER_TRIAGE_REQUIRED', configuration='UNKNOWN: supply repository authority; absence is not not-configured')


def coverage(d):
    source = os.getenv('PR_EVIDENCE_POLICY')
    if not source:
        return {'state': 'UNKNOWN', 'reason': 'repository authority not supplied'}
    try:
        with open(source) as f:
            policy = json.load(f)
    except (OSError, ValueError) as e:
        raise ReadError('cannot read evidence policy: ' + str(e))
    if not isinstance(policy, dict) or not isinstance(policy.get('source'), str) or not policy['source']:
        raise ReadError('policy needs authority source')
    result = {'source': policy['source'], 'required_checks': {}, 'required_reviewers': {}, 'optional_not_configured': {}}
    for field in ('required_checks', 'required_reviewers'):
        if not isinstance(policy.get(field), list) or any(not isinstance(n, str) or not n for n in policy[field]):
            raise ReadError('invalid policy ' + field)
    for name in policy['required_checks']:
        rows = [c for c in d['checks'] if c['name'] == name]
        matches = [{'kind': 'check', 'id': c['id'], 'app': c['app'],
                    'state': c['conclusion'] if c['status'] == 'completed' else 'pending'} for c in rows]
        # Status history is newest-first. Preserve the latest status per producer.
        producers = set()
        for status in d['statuses']:
            if status['context'].casefold() != name.casefold():
                continue
            producer = status['creator']['login']
            if producer not in producers:
                matches.append({'kind': 'status', 'id': status['id'], 'creator': producer, 'state': status['state']})
                producers.add(producer)
        result['required_checks'][name] = {
            'state': 'absent' if not matches else ('success' if all(m['state'] == 'success' for m in matches) else 'blocked'),
            'matches': matches}
    for login in policy['required_reviewers']:
        rows = sorted([r for r in d['reviews_on_head'] if r['user']['login'] == login], key=lambda r: r['id'])
        state = 'absent'
        for review in rows:
            if review['state'] in ('APPROVED', 'DISMISSED', 'CHANGES_REQUESTED') or state != 'CHANGES_REQUESTED':
                state = review['state']
        history = sorted([r for r in d['reviews_on_head'] + d['reviews_on_older_commits']
                          if r['user']['login'] == login], key=lambda r: r['id'])
        objection = False
        for review in history:
            if review['state'] == 'CHANGES_REQUESTED':
                objection = True
            elif review['state'] in ('APPROVED', 'DISMISSED'):
                objection = False
        result['required_reviewers'][login] = 'CHANGES_REQUESTED' if objection else state
    optional = policy.get('optional_not_configured', {})
    if not isinstance(optional, dict) or any(not isinstance(k, str) or not isinstance(v, str) or not v for k, v in optional.items()):
        raise ReadError('optional not-configured requires positive evidence strings')
    if set(optional) & set(policy['required_reviewers']):
        raise ReadError('required reviewer cannot be exempted as optional')
    result['optional_not_configured'] = optional
    result['state'] = 'CALLER_TRIAGE_REQUIRED'
    return result


def current_rate_limit(d, pr, repo):
    comments = [c for c in d['issue_comments'] if c.get('user', {}).get('login') == 'coderabbitai[bot]'
                and re.search(r'rate limit(ed| exceeded)|review limit reached', c['body'], re.I)]
    if not comments:
        return False
    def timestamp(value):
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    commit = gh('api', f"repos/{repo}/commits/{d['head']}")
    cutoff = timestamp(commit['commit']['committer']['date'])
    owner, name = repo.split('/')
    query = 'query($owner:String!,$name:String!,$pr:Int!){repository(owner:$owner,name:$name){pullRequest(number:$pr){timelineItems(last:1,itemTypes:[HEAD_REF_FORCE_PUSHED_EVENT]){nodes{... on HeadRefForcePushedEvent{createdAt}}}}}}'
    events = gh('api', 'graphql', '-f', 'query=' + query, '-f', 'owner=' + owner, '-f', 'name=' + name, '-F', 'pr=' + pr)['data']['repository']['pullRequest']['timelineItems']['nodes']
    for event in events:
        cutoff = max(cutoff, timestamp(event['createdAt']))
    return any(timestamp(c.get('updated_at') or c['created_at']) >= cutoff for c in comments)


def main():
    global request_deadline
    request_deadline = None
    mode, pr, repo = sys.argv[1:4]
    if mode not in ('status', 'ci', 'coderabbit') or not re.fullmatch('[1-9][0-9]*', pr) or not re.fullmatch(r'[\w.-]+/[\w.-]+', repo):
        return 2
    minutes = sys.argv[4] if len(sys.argv) > 4 else '20'
    interval = os.getenv('WAIT_INTERVAL', '30')
    after = os.getenv('WAIT_AFTER_RUN', '')
    if not minutes.isdigit() or not interval.isdigit() or (after and not after.isdigit()):
        return 2
    started = time.monotonic()
    deadline = started + int(minutes) * 60
    request_deadline = None if mode == 'status' else deadline
    first_run_deadline = started + 180
    pinned = None
    while True:
        try:
            d = collect(pr, repo)
            if d['state'] == 'HEAD_MOVED' or (pinned and d['head'] != pinned):
                print(json.dumps(dict(state='HEAD_MOVED', head=d['head'])))
                return 6
            pinned = d['head']
            d['coverage'] = coverage(d)
            if mode == 'status':
                print(json.dumps(d))
                return 0
            state, rc = 'PENDING', 3
            if mode == 'ci':
                rows = d['workflows']
                if not rows:
                    if time.monotonic() >= first_run_deadline:
                        state, rc = 'NO_RUNS', 4
                elif all(r['status'] == 'completed' and r['conclusion'] == 'success' for r in rows):
                    state, rc = 'PASS', 0
                elif any(r['status'] == 'completed' and r['conclusion'] not in ('success', None) for r in rows):
                    state, rc = 'FAIL', 1
            else:
                rows = [c for c in d['checks'] if c['name'] == 'CodeRabbit']
                c = max(rows, key=lambda c: c['id']) if rows else None
                if c and c['status'] == 'completed':
                    if c['conclusion'] == 'skipped':
                        state, rc = ('PENDING', 3) if str(c['id']) == after else ('PAUSED', 7)
                    elif c['conclusion'] == 'success':
                        state, rc = 'PASS', 0
                    else:
                        state, rc = 'FAIL', 1
                if c and not (c['status'] == 'completed' and c['conclusion'] == 'skipped' and str(c['id']) == after):
                    after = ''
                if rc == 3 and current_rate_limit(d, pr, repo):
                    state, rc = 'RATE_LIMITED_EVIDENCE', 5
            # Reread before evidence verdicts while budget remains. Strict expiry
            # returns TIMEOUT with unknown sources, without another API read.
            if head(pr, repo) != pinned:
                state, rc = 'HEAD_MOVED', 6
            if rc != 3 or time.monotonic() >= deadline:
                print(json.dumps(dict(state='TIMEOUT' if rc == 3 else state, head=pinned, run=c['id'] if mode == 'coderabbit' and c else None, wait_after_run=after)))
                return rc
            time.sleep(min(int(interval), max(0, deadline - time.monotonic())))
        except WaitTimeout:
            print(json.dumps(dict(state='TIMEOUT', head=pinned, sources='unknown', wait_after_run=after)))
            return 3
        except (ReadError, KeyError, TypeError, ValueError, AttributeError, OSError) as e:
            print(json.dumps(dict(state='READ_ERROR', head=pinned, error=str(e), sources='unknown')), flush=True)
            return 5 if 'rate limit' in str(e).lower() else 8


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, IndexError):
        sys.exit(2)
