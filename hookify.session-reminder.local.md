---
description: Remind to save session context to Pinecone
hooks:
  - event: Stop
    action: display
    message: "📌 Remember to save your session! Say: end session"
---

# Session Reminder Rule

When a conversation stops or the user is about to exit, remind them to save their session context to Pinecone.
