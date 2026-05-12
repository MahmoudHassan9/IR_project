"""
Mini Search Engine – Flask Backend (Elasticsearch)
====================================================
Endpoints:
  POST /api/build-index   – Index a folder with selected file formats
  GET  /api/search        – Search with filters, pagination, snippet highlighting
  GET  /api/stats         – Index stats (total docs, by-type, top-10 terms)

Requires:
  pip install "elasticsearch==8.13.0" flask flask-cors PyPDF2 openpyxl
  Elasticsearch 8.x running on http://localhost:9200
"""

import os
import json
import csv
import math
from datetime import datetime
from collections import Counter
from pathlib import Path

from flask import Flask, request, jsonify
from flask_cors import CORS
from elasticsearch import Elasticsearch, helpers
from elasticsearch.exceptions import ConnectionError as ESConnectionError

try:
    from PyPDF2 import PdfReader
    HAS_PDF = True
except ImportError:
    HAS_PDF = False

try:
    import openpyxl
    HAS_XLSX = True
except ImportError:
    HAS_XLSX = False

# ─────────────────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app)

ES_HOST          = "http://localhost:9200"
INDEX_NAME       = "mini_search"
RESULTS_PER_PAGE = 5

es = Elasticsearch(hosts=[ES_HOST])

# ── Elasticsearch index mapping ───────────────────────────────────────────────
INDEX_MAPPING = {
    "settings": {
        "analysis": {
            "analyzer": {
                "content_analyzer": {
                    "type":      "custom",
                    "tokenizer": "standard",
                    "filter":    ["lowercase", "stop", "snowball"],
                }
            }
        }
    },
    "mappings": {
        "properties": {
            "filename": {
                "type":     "text",
                "analyzer": "standard",
                "fields":   {"keyword": {"type": "keyword"}},
            },
            "file_path": {"type": "keyword"},
            "file_type": {"type": "keyword"},
            # ✅ fielddata=True enables terms aggregation on this text field
            "content": {
                "type":      "text",
                "analyzer":  "content_analyzer",
                "fielddata": True,
            },
            "modified": {"type": "date"},
        }
    },
}


def ensure_connected() -> bool:
    try:
        return es.ping()
    except ESConnectionError:
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Text extractors
# ─────────────────────────────────────────────────────────────────────────────

def extract_txt(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def extract_pdf(path: str) -> str:
    if not HAS_PDF:
        return ""
    reader = PdfReader(path)
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def extract_json(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        data = json.load(f)
    parts: list[str] = []

    def _walk(obj):
        if isinstance(obj, dict):
            for v in obj.values():
                _walk(v)
        elif isinstance(obj, list):
            for v in obj:
                _walk(v)
        elif isinstance(obj, str):
            parts.append(obj)

    _walk(data)
    return " ".join(parts)


def extract_csv(path: str) -> str:
    rows = []
    with open(path, newline="", encoding="utf-8", errors="ignore") as f:
        reader = csv.reader(f)
        for row in reader:
            rows.append(" ".join(row))
    return "\n".join(rows)


def extract_xlsx(path: str) -> str:
    if not HAS_XLSX:
        return ""
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    parts = []
    for ws in wb.worksheets:
        for row in ws.iter_rows(values_only=True):
            parts.extend(str(c) for c in row if c is not None)
    return " ".join(parts)


EXTRACTORS = {
    "txt":  extract_txt,
    "pdf":  extract_pdf,
    "json": extract_json,
    "csv":  extract_csv,
    "xlsx": extract_xlsx,
}


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/build-index
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/api/build-index", methods=["POST"])
def build_index():
    if not ensure_connected():
        return jsonify({
            "success": False,
            "error": f"Cannot connect to Elasticsearch at {ES_HOST}. "
                     "Make sure it is running.",
        }), 503

    body    = request.get_json(force=True)
    folder  = body.get("folder_path", "").strip()
    formats = [f.lower().lstrip(".") for f in body.get("formats", [])]

    if not folder or not os.path.isdir(folder):
        return jsonify({"success": False, "error": f"Folder not found: {folder}"}), 400
    if not formats:
        return jsonify({"success": False, "error": "No formats selected."}), 400

    # Delete + recreate index for a clean build
    if es.indices.exists(index=INDEX_NAME):
        es.indices.delete(index=INDEX_NAME)
    es.indices.create(index=INDEX_NAME, body=INDEX_MAPPING)

    by_type: Counter = Counter()
    actions = []

    for root, _, files in os.walk(folder):
        for fname in files:
            ext = Path(fname).suffix.lstrip(".").lower()
            if ext not in formats:
                continue
            fpath     = os.path.join(root, fname)
            extractor = EXTRACTORS.get(ext)
            if extractor is None:
                continue
            try:
                content = extractor(fpath)
                mtime   = datetime.fromtimestamp(
                    os.path.getmtime(fpath)
                ).isoformat()
                actions.append({
                    "_index": INDEX_NAME,
                    "_id":    fpath,
                    "_source": {
                        "filename":  fname,
                        "file_path": fpath,
                        "file_type": ext,
                        "content":   content,
                        "modified":  mtime,
                    },
                })
                by_type[ext] += 1
            except Exception as e:
                print(f"[WARN] Skipping {fpath}: {e}")

    if actions:
        helpers.bulk(es, actions)
        es.indices.refresh(index=INDEX_NAME)

    total = sum(by_type.values())
    return jsonify({"success": True, "doc_count": total, "by_type": dict(by_type)})


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/search
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/api/search", methods=["GET"])
def search():
    if not ensure_connected():
        return jsonify({"error": f"Cannot connect to Elasticsearch at {ES_HOST}"}), 503

    q_str     = request.args.get("q", "").strip()
    from_date = request.args.get("from_date", "").strip()
    to_date   = request.args.get("to_date", "").strip()
    file_type = request.args.get("file_type", "").strip().lower()
    page      = max(1, int(request.args.get("page", 1)))

    if not q_str:
        return jsonify({"results": [], "total": 0, "page": 1, "total_pages": 0})

    if not es.indices.exists(index=INDEX_NAME):
        return jsonify({"error": "Index not built yet. Go to the Index tab first."}), 503

    # ── Main query ─────────────────────────────────────────────────────────────
    # query_string supports all IR syntax:
    #   Boolean  →  python AND flask  |  java OR python  |  search NOT google
    #   Grouping →  (python OR java) AND search
    #   Phrase   →  "information retrieval"
    #   Fuzzy    →  retrival~
    #   Wildcard →  inform*  |  ?earch
    must_clauses = [
        {
            "query_string": {
                "query":                  q_str,
                "fields":                 ["content", "filename^2"],
                "fuzziness":              "AUTO",
                "default_operator":       "OR",
                "allow_leading_wildcard": True,
            }
        }
    ]

    # ── Filter clauses (no effect on score) ───────────────────────────────────
    filter_clauses = []

    if file_type and file_type not in ("all", ""):
        filter_clauses.append({"term": {"file_type": file_type}})

    if from_date or to_date:
        date_range: dict = {}
        if from_date:
            date_range["gte"] = from_date
        if to_date:
            date_range["lte"] = to_date
        filter_clauses.append({"range": {"modified": date_range}})

    es_query = {
        "bool": {
            "must":   must_clauses,
            "filter": filter_clauses,
        }
    }

    # ── Highlight config ───────────────────────────────────────────────────────
    highlight_cfg = {
        "fields": {
            "content": {
                "fragment_size":       200,
                "number_of_fragments": 1,
                "pre_tags":            ["<mark>"],
                "post_tags":           ["</mark>"],
            }
        }
    }

    # ── Execute ────────────────────────────────────────────────────────────────
    offset = (page - 1) * RESULTS_PER_PAGE
    try:
        resp = es.search(
            index=INDEX_NAME,
            query=es_query,
            highlight=highlight_cfg,
            from_=offset,
            size=RESULTS_PER_PAGE,
            track_total_hits=True,
        )
    except Exception as e:
        return jsonify({"error": f"Search failed: {e}"}), 400

    total       = resp["hits"]["total"]["value"]
    total_pages = max(1, math.ceil(total / RESULTS_PER_PAGE))

    items = []
    for hit in resp["hits"]["hits"]:
        src     = hit["_source"]
        snippet = " … ".join(hit.get("highlight", {}).get("content", []))
        items.append({
            "filename":      src["filename"],
            "file_path":     src["file_path"],
            "file_type":     src["file_type"],
            "score":         round(hit["_score"] or 0, 4),
            "modified_date": src.get("modified", ""),
            "snippet":       snippet,
        })

    # ── Did you mean? (only when zero results) ─────────────────────────────────
    did_you_mean = None
    if total == 0:
        try:
            sug_resp = es.search(
                index=INDEX_NAME,
                suggest={
                    "text": q_str,
                    "phrase_suggest": {
                        "phrase": {
                            "field":     "content",
                            "size":      1,
                            "gram_size": 3,
                            "direct_generator": [
                                {"field": "content", "suggest_mode": "missing"}
                            ],
                        }
                    },
                },
                size=0,
            )
            options = (
                sug_resp.get("suggest", {})
                .get("phrase_suggest", [{}])[0]
                .get("options", [])
            )
            if options:
                did_you_mean = options[0]["text"]
        except Exception:
            pass

    return jsonify({
        "results":      items,
        "total":        total,
        "page":         page,
        "total_pages":  total_pages,
        "did_you_mean": did_you_mean,
    })


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/stats
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/api/stats", methods=["GET"])
def stats():
    if not ensure_connected():
        return jsonify({
            "indexed":    False,
            "total_docs": 0,
            "by_type":    {},
            "top_terms":  [],
            "error":      f"Cannot connect to Elasticsearch at {ES_HOST}",
        })

    if not es.indices.exists(index=INDEX_NAME):
        return jsonify({"indexed": False, "total_docs": 0, "by_type": {}, "top_terms": []})

    # Total document count
    total = es.count(index=INDEX_NAME)["count"]

    # Documents grouped by file type
    agg_resp = es.search(
        index=INDEX_NAME,
        size=0,
        aggregations={"by_type": {"terms": {"field": "file_type", "size": 20}}},
    )
    by_type = {
        b["key"]: b["doc_count"]
        for b in agg_resp["aggregations"]["by_type"]["buckets"]
    }

    # ✅ Top 10 terms using terms aggregation on content field (fielddata=True)
    # This works with any number of documents unlike significant_text
    top_terms = []
    try:
        terms_resp = es.search(
            index=INDEX_NAME,
            size=0,
            aggregations={
                "top_terms": {
                    "terms": {
                        "field": "content",
                        "size":  10,
                    }
                }
            },
        )
        for b in terms_resp["aggregations"]["top_terms"]["buckets"]:
            top_terms.append({"term": b["key"], "count": int(b["doc_count"])})
    except Exception:
        top_terms = []

    return jsonify({
        "indexed":    True,
        "total_docs": total,
        "by_type":    by_type,
        "top_terms":  top_terms,
    })


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Starting Mini Search Engine backend on http://localhost:5000")
    print(f"Connecting to Elasticsearch at {ES_HOST}")
    if ensure_connected():
        print("✓ Elasticsearch is reachable")
    else:
        print("✗ WARNING: Elasticsearch is NOT reachable — start it before indexing")
    app.run(debug=True, port=5000)