# CRM module

Organization-scoped customer relationship primitives. This is application
infrastructure, not a single vertical: contacts, companies, leads,
opportunities, pipelines, notes, tasks, tags, and an activity timeline.

## Enablement

CRM is a generation-time module (`config/foundation/modules/crm.yml`).
When the module is present on disk it is available to every signed-in
member of the current organization. There is no separate runtime flag.

Omit at generation with:

```
./bin/foundation-modules omit crm
```

## Security

Every CRM row carries `organization_id`. Controllers load records only
through `for_organization(current_organization)`. Probing an id from
another organization returns the same 404 as a missing id. Owner and
assignee pickers are limited to members of the current organization.
Cross-module foreign keys are not used.

## Surfaces

Authenticated routes under `/crm`:

- Overview dashboard
- Contacts, companies, leads, opportunities (CRUD + filters)
- Lead/opportunity ownership assignment
- Opportunity stage movement
- Pipelines and stages
- Tasks (including complete)
- Tags
- Per-record notes and activity timeline

## Deferred

Drag-and-drop kanban, full-text search, bulk operations, import/export,
and reporting are intentionally out of scope for this milestone.
