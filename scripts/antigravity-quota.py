#!/usr/bin/env python3
import os
import glob
import re
import json
import sqlite3
import datetime
import urllib.request
import urllib.error

CACHE_FILE = '/tmp/antigravity_quota_cache.json'
STATE_CACHE_FILE = '/tmp/antigravity_ls_state.json'
GEMINI_WEB_FILE = os.path.expanduser('~/.config/quickshell/inir/scripts/gemini_web_quota.json')
CACHE_TTL_SECONDS = 15  # Quota cache TTL

def get_gemini_web_quota():
    if not os.path.exists(GEMINI_WEB_FILE):
        return None
    try:
        with open(GEMINI_WEB_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
        # Valid if updated in the last 48 hours
        updated_at = data.get('_updatedAt', 0)
        if datetime.datetime.now().timestamp() - updated_at > 48 * 3600:
            return None
        return data
    except Exception:
        return None

def format_relative_time(iso_str):
    if not iso_str:
        return ''
    try:
        dt = datetime.datetime.fromisoformat(iso_str.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        diff = dt - now
        total_seconds = int(diff.total_seconds())
        if total_seconds <= 0:
            return 'Ahora'
        days = total_seconds // 86400
        rem = total_seconds % 86400
        hours = rem // 3600
        rem = rem % 3600
        minutes = rem // 60
        if days > 0:
            return f'{days}d {hours}h'
        elif hours > 0:
            return f'{hours}h {minutes}m'
        else:
            return f'{minutes}m'
    except Exception:
        return iso_str

def get_live_task_state():
    db_path = os.path.expanduser('~/.gemini/antigravity/conversation_summaries.db')
    if not os.path.exists(db_path):
        return False, '', ''
    try:
        conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
        cur = conn.cursor()
        cur.execute('SELECT not_fully_idle, title, status FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1')
        row = cur.fetchone()
        conn.close()
        if row:
            busy = bool(row[0]) or ('RUNNING' in str(row[2]))
            title = row[1] or ''
            status = row[2] or ''
            return busy, title, status
    except Exception:
        pass
    return False, '', ''

def get_ls_connection():
    # 1. Check cached PID & port
    target_pid = None
    csrf_token = None
    port = None

    if os.path.exists(STATE_CACHE_FILE):
        try:
            with open(STATE_CACHE_FILE, 'r') as f:
                c = json.load(f)
                cached_pid = c.get('pid')
                if cached_pid and os.path.exists(f'/proc/{cached_pid}'):
                    target_pid = cached_pid
                    csrf_token = c.get('csrf')
                    port = c.get('port')
        except Exception:
            pass

    # 2. If not found or stale, scan /proc for language_server
    if not target_pid or not csrf_token:
        for p in glob.glob('/proc/[0-9]*/cmdline'):
            try:
                with open(p, 'rb') as f:
                    content = f.read().split(b'\x00')
                    if any(b'language_server' in arg for arg in content):
                        pid = int(p.split('/')[2])
                        token = None
                        for i, arg in enumerate(content):
                            if arg == b'--csrf_token' and i + 1 < len(content):
                                token = content[i+1].decode('utf-8')
                        if token:
                            target_pid = pid
                            csrf_token = token
                            break
            except Exception:
                continue

    if not target_pid or not csrf_token:
        return None, None

    # 3. Find port if not cached
    if not port:
        log_path = os.path.expanduser('~/.config/Antigravity/logs/language_server.log')
        if os.path.exists(log_path):
            with open(log_path, 'r', errors='ignore') as f:
                for line in f:
                    if 'for HTTP' in line and 'listening on random port at' in line:
                        m = re.search(r'listening on random port at (\d+) for HTTP', line)
                        if m:
                            port = int(m.group(1))

    # Save cache
    if target_pid and csrf_token and port:
        try:
            with open(STATE_CACHE_FILE, 'w') as f:
                json.dump({'pid': target_pid, 'csrf': csrf_token, 'port': port}, f)
        except Exception:
            pass

    return csrf_token, port

def fetch_quota():
    # Check quota cache
    now = datetime.datetime.now().timestamp()
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, 'r') as f:
                cached = json.load(f)
                if now - cached.get('timestamp', 0) < CACHE_TTL_SECONDS:
                    return cached.get('data')
        except Exception:
            pass

    csrf, port = get_ls_connection()
    if not csrf or not port:
        return None

    url = f'http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary'
    req = urllib.request.Request(
        url,
        data=b'{}',
        headers={
            'Content-Type': 'application/json',
            'x-codeium-csrf-token': csrf
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            data = json.loads(resp.read().decode())
            # Save to cache
            try:
                with open(CACHE_FILE, 'w') as f:
                    json.dump({'timestamp': now, 'data': data}, f)
            except Exception:
                pass
            return data
    except Exception:
        # Invalid port or connection error, clear state cache so next run rediscovers
        if os.path.exists(STATE_CACHE_FILE):
            try: os.remove(STATE_CACHE_FILE)
            except: pass
        return None

def main():
    busy, current_task, status = get_live_task_state()
    quota_raw = fetch_quota()

    result = {
        'available': quota_raw is not None,
        'running': quota_raw is not None,
        'busy': busy,
        'currentTask': current_task,
        'primaryPercentage': 100,
        'primaryFraction': 1.0,
        'primaryLabel': '5h Limit',
        'primaryResetIn': '',
        'groups': []
    }

    if quota_raw and 'response' in quota_raw and 'groups' in quota_raw['response']:
        groups_data = []
        for g in quota_raw['response']['groups']:
            group_name = g.get('displayName', '')
            buckets = []
            for b in g.get('buckets', []):
                frac = b.get('remainingFraction', 1.0)
                pct = int(round(frac * 100))
                reset_iso = b.get('resetTime', '')
                reset_relative = format_relative_time(reset_iso)
                bucket_info = {
                    'bucketId': b.get('bucketId', ''),
                    'displayName': b.get('displayName', ''),
                    'percentage': pct,
                    'fraction': frac,
                    'resetIn': reset_relative,
                    'rawResetTime': reset_iso
                }
                buckets.append(bucket_info)

                # Find primary for the bar: prefer gemini 5-hour limit
                if b.get('bucketId') == 'gemini-5h':
                    result['primaryPercentage'] = pct
                    result['primaryFraction'] = frac
                    result['primaryLabel'] = '5h Limit'
                    result['primaryResetIn'] = reset_relative

            groups_data.append({
                'displayName': group_name,
                'description': g.get('description', ''),
                'buckets': buckets
            })
        result['groups'] = groups_data

    # Check for Gemini Web sync from Zen browser extension
    web_data = get_gemini_web_quota()
    if web_data:
        result['available'] = True
        tier_label = web_data.get('tier', 'Gemini Web')
        model_label = web_data.get('model', '')
        desc = f"Zen Browser ({tier_label} - {model_label})" if model_label else f"Zen Browser ({tier_label})"
        
        web_buckets = web_data.get('buckets')
        if not web_buckets:
            pct = int(web_data.get('percentage', 100))
            frac = float(web_data.get('fraction', 1.0))
            reset_in = web_data.get('resetIn', '')
            web_buckets = [
                {
                    'bucketId': 'gemini-web-budget',
                    'displayName': 'Presupuesto de Cómputo',
                    'percentage': pct,
                    'fraction': frac,
                    'resetIn': reset_in,
                    'rawResetTime': ''
                }
            ]

        result['groups'].append({
            'displayName': 'Gemini Web (Zen)',
            'description': desc,
            'buckets': web_buckets
        })

    print(json.dumps(result))

if __name__ == '__main__':
    main()
