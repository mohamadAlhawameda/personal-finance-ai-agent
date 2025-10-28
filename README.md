# HomeBudget Buddy (AI Chatbot Prototype)

This project demonstrates a simple AI-powered budgeting assistant built with:
- n8n (workflow automation)
- Postgres + pgvector (vector storage)
- Google Gemini (LLM + embeddings)
- Docker Compose for local deployment
- Cloudflare Tunnel for public access

It can:
- Ingest financial data (PDF)
- Store and retrieve embeddings
- Answer budget questions conversationally
- Maintain short-term chat memory

### Setup
1. Clone repo
2. Run `./setup.sh`
3. Import `INGESTION.json` and `CHAT.json`
4. Add your Gemini + Postgres credentials in n8n
5. Run ingestion, then chat via the public link


### Credits
Built as a frugal prototype for McMaster University (GENTECH 3DM3).
