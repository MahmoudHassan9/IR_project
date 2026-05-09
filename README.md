# Mini Search Engine

A Flutter web frontend + Python (Whoosh) backend for the Information Retrieval final project.

---

## How to Run

### Backend (Python):
```bash
pip install flask flask-cors whoosh PyPDF2 openpyxl
python backend/app.py
```

### Frontend (Flutter Web):
```bash
flutter pub get
flutter run -d chrome
```

---

## Project Structure

```
mini_search_engine/
├── lib/                        # Flutter source
│   ├── main.dart               # App entry point + shell layout
│   ├── models/models.dart      # Data models
│   ├── services/
│   │   ├── api_service.dart    # HTTP calls to backend
│   │   └── app_state.dart      # Global state (Provider)
│   └── screens/
│       ├── index_screen.dart   # Step 1 – pick formats + build
│       ├── search_screen.dart  # Step 2 – search + results
│       └── stats_screen.dart   # Step 3 – stats + charts
├── backend/
│   └── app.py                  # Flask + Whoosh backend
└── pubspec.yaml
```

---

## 1 – Backend Setup

```bash
cd backend
pip install flask flask-cors whoosh PyPDF2 openpyxl
python app.py          # Starts on http://localhost:5000
```

### Supported file formats
| Format | Notes |
|--------|-------|
| TXT    | UTF-8 plain text |
| PDF    | Text extracted via PyPDF2 |
| JSON   | All string values flattened into one document |
| CSV    | Each row's values joined; all rows = one document |
| Excel (.xlsx) | All cell values flattened into one document |

---

## 2 – Flutter Web Setup

```bash
# Install Flutter: https://flutter.dev/docs/get-started/install
flutter pub get
flutter run -d chrome          # dev mode
flutter build web              # production build → build/web/
```

---

## 3 – Using the App

### Index Tab
1. Enter the full path to the folder you want to index.
2. Toggle which file formats to include.
3. Click **Build / Rebuild Index**.

### Search Tab
Supports all standard Lucene/Whoosh query syntax:

| Syntax | Example |
|--------|---------|
| Boolean AND | `machine AND learning` |
| Boolean OR | `retrieval OR search` |
| Boolean NOT | `elastic NOT kibana` |
| Grouping | `(python OR java) AND search` |
| Phrase | `"information retrieval"` |
| Fuzzy | `retrival~` or `retrival~2` |
| Wildcard | `inform*` or `?earch` |

- Use the **Filters** panel to narrow by modification date and/or file type.
- Results show filename, file type, relevance score, modification date, and a **highlighted snippet**.
- If a query returns nothing, a **Did you mean?** suggestion appears.
- Results are paged: **5 per page** with previous/next navigation.

### Stats Tab
- Total indexed documents.
- Breakdown by file type (pie chart + table).
- Top 10 most frequent terms (bar chart + chips).

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/build-index` | Build or rebuild the index |
| GET | `/api/search` | Search with query + filters |
| GET | `/api/stats` | Retrieve index statistics |

### POST `/api/build-index`
```json
{ "folder_path": "/path/to/docs", "formats": ["pdf","txt","json"] }
```
Response:
```json
{ "success": true, "doc_count": 42, "by_type": {"pdf": 10, "txt": 32} }
```

### GET `/api/search`
| Param | Description |
|-------|-------------|
| `q` | Query string |
| `from_date` | YYYY-MM-DD (optional) |
| `to_date` | YYYY-MM-DD (optional) |
| `file_type` | pdf/txt/json/csv/xlsx (optional) |
| `page` | Page number (default 1) |

Response:
```json
{
  "results": [
    {
      "filename": "report.pdf",
      "file_type": "pdf",
      "score": 4.21,
      "modified_date": "2024-03-15T10:30:00",
      "snippet": "… <mark>information</mark> retrieval is … "
    }
  ],
  "total": 18,
  "page": 1,
  "total_pages": 4,
  "did_you_mean": null
}
```

### GET `/api/stats`
```json
{
  "indexed": true,
  "total_docs": 42,
  "by_type": { "pdf": 10, "txt": 32 },
  "top_terms": [
    { "term": "search", "count": 340 },
    ...
  ]
}
```
