"""
Mini Search Engine – Flask Backend
===================================
Endpoints:
  POST /api/build-index   – Index a folder with selected file formats
  GET  /api/search        – Search with filters, pagination, snippet highlighting
  GET  /api/stats         – Index stats (total docs, by-type, top-10 terms)

Requires:
  pip install whoosh flask flask-cors pypdf2 openpyxl
"""

import os
import json
import csv
import math
import string
from datetime import datetime
from collections import Counter
from pathlib import Path

from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Whoosh imports ────────────────────────────────────────────────────────────
from whoosh import index, qparser, highlight
from whoosh.fields import Schema, TEXT, ID, STORED, DATETIME, KEYWORD
from whoosh.qparser import MultifieldParser, FuzzyTermPlugin, WildcardPlugin
from whoosh.analysis import StemmingAnalyzer
from whoosh.searching import Searcher

# ── Optional readers ──────────────────────────────────────────────────────────
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

INDEX_DIR = ".search_index"
RESULTS_PER_PAGE = 5

# ── Whoosh schema ─────────────────────────────────────────────────────────────
def get_schema():
    return Schema(
        doc_id    = ID(stored=True, unique=True),
        filename  = ID(stored=True),   # must be ID, not STORED — used in MultifieldParser
        file_path = STORED(),
        file_type = KEYWORD(stored=True),
        content   = TEXT(analyzer=StemmingAnalyzer(), stored=True),
        modified  = DATETIME(stored=True),
    )

def get_index():
    if index.exists_in(INDEX_DIR):
        return index.open_dir(INDEX_DIR)
    return None


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
            for v in obj.values(): _walk(v)
        elif isinstance(obj, list):
            for v in obj: _walk(v)
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
    body    = request.get_json(force=True)
    folder  = body.get("folder_path", "").strip()
    formats = [f.lower().lstrip(".") for f in body.get("formats", [])]

    if not folder or not os.path.isdir(folder):
        return jsonify({"success": False, "error": f"Folder not found: {folder}"}), 400
    if not formats:
        return jsonify({"success": False, "error": "No formats selected."}), 400

    os.makedirs(INDEX_DIR, exist_ok=True)
    ix = index.create_in(INDEX_DIR, get_schema())
    writer = ix.writer()

    by_type: Counter = Counter()

    for root, _, files in os.walk(folder):
        for fname in files:
            ext = Path(fname).suffix.lstrip(".").lower()
            if ext not in formats:
                continue
            fpath = os.path.join(root, fname)
            extractor = EXTRACTORS.get(ext)
            if extractor is None:
                continue
            try:
                content = extractor(fpath)
                mtime   = datetime.fromtimestamp(os.path.getmtime(fpath))
                writer.add_document(
                    doc_id    = fpath,
                    filename  = fname,
                    file_path = fpath,
                    file_type = ext,
                    content   = content,
                    modified  = mtime,
                )
                by_type[ext] += 1
            except Exception as e:
                print(f"[WARN] Skipping {fpath}: {e}")

    writer.commit()
    total = sum(by_type.values())
    return jsonify({"success": True, "doc_count": total, "by_type": dict(by_type)})


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/search
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/api/search", methods=["GET"])
def search():
    q_str     = request.args.get("q", "").strip()
    from_date = request.args.get("from_date", "").strip()
    to_date   = request.args.get("to_date", "").strip()
    file_type = request.args.get("file_type", "").strip().lower()
    page      = max(1, int(request.args.get("page", 1)))

    if not q_str:
        return jsonify({"results": [], "total": 0, "page": 1, "total_pages": 0})

    ix = get_index()
    if ix is None:
        return jsonify({"error": "Index not built yet. Go to the Index tab first."}), 503

    # ── Build query ──────────────────────────────────────────────────────────
    og = qparser.OrGroup.factory(0.9)
    qp = MultifieldParser(["content", "filename"], schema=ix.schema, group=og)
    qp.add_plugin(FuzzyTermPlugin())
    qp.add_plugin(WildcardPlugin())

    try:
        query = qp.parse(q_str)
    except Exception as e:
        # ✅ FIX: return the actual parse error so it's easier to debug
        return jsonify({"error": f"Invalid query syntax: {e}"}), 400

    # ── Date filter ──────────────────────────────────────────────────────────
    filter_query = None
    if from_date or to_date:
        try:
            from whoosh.query import DateRange
            fd = datetime.strptime(from_date, "%Y-%m-%d") if from_date else None
            td = datetime.strptime(to_date,   "%Y-%m-%d") if to_date   else None
            filter_query = DateRange("modified", fd, td)
        except Exception:
            pass

    # ── File-type filter ─────────────────────────────────────────────────────
    from whoosh.query import Term as WTerm, And as WAnd
    if file_type and file_type not in ("all", ""):
        ft_q  = WTerm("file_type", file_type)
        query = WAnd([query, ft_q])

    if filter_query:
        query = WAnd([query, filter_query])

    # ── Execute search ───────────────────────────────────────────────────────
    with ix.searcher() as s:
        offset      = (page - 1) * RESULTS_PER_PAGE
        results_raw = s.search(query, limit=offset + RESULTS_PER_PAGE + 1)

        total       = len(results_raw)
        total_pages = max(1, math.ceil(total / RESULTS_PER_PAGE))

        hlt = highlight.Highlighter(
            fragmenter=highlight.ContextFragmenter(maxchars=200, surround=40),
            formatter=highlight.HtmlFormatter(tagname="mark", between=" … "),
        )

        items = []
        for i, hit in enumerate(results_raw):
            if i < offset:
                continue
            if len(items) >= RESULTS_PER_PAGE:
                break
            snippet = hlt.highlight_hit(hit, "content", minscore=0) or ""
            items.append({
                "filename":      hit["filename"],
                "file_path":     hit["file_path"],
                "file_type":     hit["file_type"],
                "score":         round(hit.score, 4),
                "modified_date": hit["modified"].isoformat() if hit["modified"] else "",
                "snippet":       snippet,
            })

        # ── Did you mean? ────────────────────────────────────────────────────
        did_you_mean = None
        if total == 0:
            try:
                corrected = s.correct_query(query, qp)
                if corrected.query != query:
                    did_you_mean = str(corrected.string)
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
    ix = get_index()
    if ix is None:
        return jsonify({"indexed": False, "total_docs": 0, "by_type": {}, "top_terms": []})

    with ix.reader() as r:
        total = r.doc_count()

        # by_type: iterate stored file_type field
        by_type: Counter = Counter()
        for docnum in r.all_doc_ids():
            fields = r.stored_fields(docnum)
            ft = fields.get("file_type", "unknown")
            # ✅ FIX: file_type may come back as bytes from Whoosh internals
            if isinstance(ft, bytes):
                ft = ft.decode("utf-8")
            by_type[ft] += 1

        # top-10 terms from the content field
        # ✅ FIX: most_distinctive_terms() yields (score, term) where term is bytes
        top_terms = []
        for freq, term in r.most_distinctive_terms("content", number=10):
            if isinstance(term, bytes):
                term = term.decode("utf-8")
            top_terms.append({"term": term, "count": int(freq)})

    return jsonify({
        "indexed":    True,
        "total_docs": total,
        "by_type":    dict(by_type),
        "top_terms":  top_terms,
    })


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Starting Mini Search Engine backend on http://localhost:5000")
    app.run(debug=True, port=5000)