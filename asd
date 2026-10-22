cat > dlpai-ctx-test.sh <<'DLPAI_CTX_END'
#!/bin/bash
# Does the model server keep a BIG prompt intact? (AI Chat sends the instructions + tool definitions + the 90-collection catalog.)
# Silent truncation (Ollama default context 4096) makes the model "lose" its tools and say it has no access. Read-only.
#   sudo bash dlpai-ctx-test.sh
set -uo pipefail
M="$(grep -E '^LLM_MODEL=' /etc/dlpai/environment 2>/dev/null | tail -1 | cut -d= -f2-)"; M="${LLM_MODEL:-$M}"
U="$(grep -E '^LLM_GATEWAY_UPSTREAM_URL=' /etc/dlpai/environment 2>/dev/null | tail -1 | cut -d= -f2-)"; U="${LLM_URL:-$U}"
echo "model: ${M:-?}   upstream: ${U:-?}"
LLM_M="$M" LLM_U="$U" python3 - <<'PY'
import json, os, urllib.request, time
m, up = os.environ.get("LLM_M") or "", (os.environ.get("LLM_U") or "").rstrip("/")
try:
    ps = json.load(urllib.request.urlopen(up + "/api/ps", timeout=6)).get("models", [])
    for x in ps: print("  Ollama reports for %s: context_length=%s" % (x.get("name"), x.get("context_length", "(not reported by this Ollama version)")))
    if not ps: print("  (no model loaded in Ollama right now)")
except Exception:
    print("  /api/ps not available (not Ollama, or older): the needle test below is the check")
def ask(words):
    filler = " ".join("Record %d: routine entry, nothing to report." % i for i in range(words // 7))
    body = {"model": m, "temperature": 0, "max_tokens": 60, "reasoning_effort": "none",
            "messages": [{"role": "user", "content": "Remember this: the secret word is MANGO-7.\n" + filler + "\nQuestion: what is the secret word? Answer with the word only."}]}
    req = urllib.request.Request("http://127.0.0.1:5560/v1/chat/completions", json.dumps(body).encode(), {"Content-Type": "application/json"})
    t = time.time(); r = json.load(urllib.request.urlopen(req, timeout=600))
    return (r["choices"][0]["message"].get("content") or ""), r.get("usage", {}).get("prompt_tokens"), time.time() - t
print("needle test (a word at the START of a long prompt, asked at the END):")
for words in (2000, 7000, 16000):
    try:
        a, tok, dt = ask(words)
    except Exception as e:
        print("  ~%5d words: request failed (%s %s)" % (words, type(e).__name__, str(e)[:80])); break
    ok = "MANGO-7" in a.upper()
    print("  ~%5d words, prompt_tokens reported=%s, %3.0f s: %s" % (words, tok, dt, "✔️ remembered" if ok else "✗ FORGOT (prompt truncated?) answer=%r" % a[:50]))
    if not ok: break
PY
DLPAI_CTX_END
sudo bash dlpai-ctx-test.sh
