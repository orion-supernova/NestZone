PocketBase generic Polls (REST, no realtime)

Overview
- Generic polls for any entity type (movie, recipe, generic)
- Items in a poll are stored in poll_items (so we’re not locked to strings)
- Votes go to poll_votes and are restricted per user via unique indexes
- Access is scoped to home members
- Backward-compatible: polls.candidates (JSON array of external IDs) supports your current client while migrating to poll_items

Prerequisites
- homes collection has a relation field members (multi-select) to users containing allowed users for that home.
- If your field name differs, update the rules in the JSON to match (e.g., household_members).

Import
1. In PocketBase Admin: Settings → Import collections → Select polls_schema.json → Import
2. Verify indexes were applied (Collections → select collection → Options → SQL Indexes)
3. Ensure homes.members exists and is populated; otherwise, temporarily relax rules to @request.auth.id != '' for testing.

Collections

polls
- home_id (relation -> homes, required)
- owner_id (relation -> users, required)
- title (text)
- type (select: movie/recipe/generic)
- status (select: draft/active/closed)
- config (json) optional (e.g., {"threshold":2,"allowMultiple":false})
- candidates (json) optional array of external IDs (for lightweight usage)
- genre (text) optional
- expires_at (date) optional
Indexes
- polls_home_status (home_id, status)
- polls_owner (owner_id)
Rules
- list/view: home membership only
- create: must be member of home; owner_id must equal @request.auth.id
- update/delete: owner-only and home member

poll_items
- poll_id (relation -> polls, required)
- entity_type (select: movie/recipe/generic) optional (defaults to poll.type)
- external_id (text, required) e.g., "tt2250912" or your recipe ID
- label (text) optional
- thumbnail_url (text) optional
- payload (json) optional: cached metadata for offline display
- order (number) optional
Indexes
- poll_items_poll (poll_id)
- poll_items_unique (poll_id, external_id) UNIQUE
Rules
- list/view: home membership
- create: home member and poll.status == 'active'
- update/delete: poll.owner-only

poll_votes
- poll_id (relation -> polls, required)
- item_id (relation -> poll_items) OR target_external_id (text) exactly one required
- vote (bool, required)
- user_id (relation -> users, required; must equal @request.auth.id)
Indexes
- poll_votes_poll (poll_id)
- poll_votes_item (item_id)
- poll_votes_user (user_id)
- poll_votes_unique_item (poll_id, item_id, user_id) UNIQUE
- poll_votes_unique_external (poll_id, target_external_id, user_id) UNIQUE
Rules
- list/view: home membership
- create: home member, poll is active, user_id == @request.auth.id, exactly one of item_id or target_external_id
- update/delete: only the vote owner can modify/delete

Usage patterns (REST)
- Create poll (lightweight, movies): POST /api/collections/polls/records with {home_id, owner_id, title, type:"movie", status:"active", candidates:["tt2250912", ...]}
- Create poll (generic): Create poll (status:"active"), then POST /api/collections/poll_items/records for each candidate with {poll_id, external_id, label, thumbnail_url, payload}
- Submit vote:
  - Lightweight: POST poll_votes with {poll_id, target_external_id:"tt2250912", vote:true, user_id:@request.auth.id}
  - Generic: POST poll_votes with {poll_id, item_id:"<poll_item_id>", vote:true, user_id:@request.auth.id}
- Close poll: PATCH /api/collections/polls/records/:id {status:"closed"}
- Fetch votes: GET /api/collections/poll_votes/records?filter=poll_id='<pollId>'&perPage=200

Client behavior tips (no SSE)
- Poll the votes endpoint every 2–5 seconds while a poll is active
- Compute results client-side; consider config.threshold for “match”
- On 400 when posting vote (unique index violation), fetch existing vote and PATCH it instead of POSTing again

Adapting rules to your schema
- If your homes collection doesn’t maintain a members relation:
  - Replace rules’ membership check with your own, or temporarily use @request.auth.id != '' and restrict by filter on client.
- If your membership is via a junction (home_members), change rule to: @collection('home_members').findOne("home_id = '"+(record.home_id)+"' && user_id = '"+(@request.auth.id)+"'") != null

Migration path from candidates JSON to poll_items
- Keep polls.candidates for movies now (current client works).
- New features (recipes, mixed polls) should use poll_items and item_id votes.
- Later, migrate Movie flow to poll_items and remove candidates JSON.

That’s it. Want me to generate a PocketBase seed script that pre-creates a demo movie poll + items so you can test end-to-end immediately?