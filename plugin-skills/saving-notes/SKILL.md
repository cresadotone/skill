---
name: saving-notes
description: >-
  Save Markdown notes in the account's private default Drive so any signed-in
  agent can pick them up later. Use when asked to save a note, update a note,
  find notes, or delete a note. Do not use notes for repository code.
---

# Save notes

{{RUNTIME}}

This is the cresa.one equivalent of Send's saving-notes skill. Notes are private Drive files under `notes/`. They are not public Sites.

- `SaveNote` writes a Markdown note and returns `noteId` plus a `revision`.
- `UpdateNote` needs that `noteId` and `expectedRevision`. It pauses for approval.
- `GetNotes` lists notes. Pass `noteId` before changing one you have only seen as a snippet.
- `DeleteNote` needs the same `noteId` and `expectedRevision`, and pauses for approval.

Do not put repository code in notes. Use a Drive folder for project files, or a Site when the person wants a public URL.
