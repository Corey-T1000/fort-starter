# Memory -- Routing Table

> Topic files in `memory/XX-name.md` hold operational knowledge.
> When the agent edits files matching a path prefix, it loads the corresponding memory file automatically.

## Memory Loading Routes

| Path prefix | Memory file | Tab title |
|---|---|---|
| `projects/example/` | `memory/60-example.md` | `workspace:example` |

## How to add a topic

1. Create `memory/XX-topic.md` using the template in `60-example.md`
2. Add a row to the routing table above
3. The agent will auto-load it when editing files in the matching path
