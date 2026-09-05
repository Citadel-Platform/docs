# An agent's name, its resources, and the seven-day rule

Two conventions that are easy to get wrong once and hard to see afterwards.
Both were learned by running into them.

## The slug

Every agent has an **artifact id** and a **slug**, and they are derived, not
chosen twice.

| | |
| --- | --- |
| Name (typed) | `Bookings Desk` |
| Artifact id | `exigence.superharness.bookings-desk` |
| Slug | `bookings-desk` |
| Resource prefix | `cit-user-test-1-acb1` + `-` + `md5("user-test-1/bookings-desk")[0:4]` |

**The name is the only thing anybody types.** The console lowercases it,
replaces every run of non-alphanumerics with a hyphen, and trims hyphens from
the ends. That slug becomes the last segment of the artifact id. The slug the
provisioning template uses is that last segment again, cut to the thirteen
characters Terraform accepts and never left ending in a hyphen.

**Why derived rather than asked for.** A second field for the slug is a second
chance to make two agents collide, and the collision is invisible: the resource
prefix is a hash of `client/slug`, so two agents sharing a slug share a Cloud
Run service name, a queue name and a pair of service accounts.

**Hyphens are allowed everywhere or the console cannot work.** `agent_slug` has
always permitted them; `agent_id` did not until F-093, so a two-word name could
not be created at all. If you are adding a validator to this path, allow
`[a-z0-9.-]` and start it with a letter.

**Thirteen characters is a real ceiling**, not a suggestion: Cloud Run service
names are bounded and the prefix already spends most of the budget. Two agents
whose slugs share their first thirteen characters will collide. Nothing checks
this yet — see the open item below.

## Derived once, then it is a fact

Everything above describes how a slug is **first** arrived at. For an agent
that already exists it is no longer a derivation — it is a record of what was
built, and re-deriving it is a defect.

`exigence.superharness` on `user-test-1` is the case that proves it. Its slug
is `wa2`; the derivation gives `superharness`. Rolling it forward from the
console derived the wrong one, read an empty Terraform state, and offered
`32 to add, 0 to change, 0 to destroy` — a second complete runtime beside the
one already serving that client's line, under different names so nothing would
even have collided. That is F-108, and it is F-095 from the other side: not
two agents sharing one state, but one agent pointed at a state that is not its
own. Both end as a plan proposing to create what already exists, which nobody
reading a summary would recognise as wrong.

So the platform reads the slug back from the build that recorded it, exactly
as it reads back the client runtime's name prefix, database and bucket (F-091),
and for the same reason: the naming happened once, and deriving it again is how
a deployment detaches from what it named. A caller's slug stands only for an
agent no applied build has ever named.

Two details, both learned the hard way:

- **An apply that ran named things, even if the job did not finish `applied`.**
  Every one of `exigence.superharness`'s thirteen builds is recorded
  `applyFailed`: Terraform created the resources and the post-apply routing
  check then failed the job. The state, the prefix and the running service are
  all real. Approval is the honest signal that an apply was launched at all —
  a job that never got past planning created nothing and named nothing.
- **The apply must run under the plan's slug**, not a freshly derived one.
  `approveAndApply` re-resolves everything else on purpose, so that a boundary
  revision published between the plan and the apply is the one the artifact is
  bound by. The slug is the exception: the plan file is written under the
  prefix the plan used, so an apply that composed a different slug could not
  find the plan at all.

## Terraform state is per agent

`provisioner/exigence-agent/<project>/<slug>`.

Per **agent**, not per project. Every other template deploys one thing per
project and is keyed that way; `exigence-agent` deploys one of several. Sharing
a state means the second agent's plan is read against the first agent's, and
Terraform proposes destroying everything the first agent is. That was F-095,
observed as `23 to add, 0 to change, 23 to destroy` against a live agent.

A build with no slug is refused rather than defaulted. Falling back to the
shared prefix is exactly the failure, done silently.

## The seven-day queue rule

**Cloud Tasks reserves a deleted queue's name for about seven days.**

A queue is named after the resource prefix, which is derived from the client id
and the agent slug. So:

- Tearing a client down and rebuilding them inside a week fails on the queue,
  *after* the apply has already created the Cloud Run service, the service
  accounts and the IAM grants — the queue is late in the graph.
- The same is true of an agent: destroy `bookings-desk` and rebuild it within
  the week and the queue name is still held.

**What to do about it.** Change the slug. `wa` became `wa2` for exactly this
reason. The prefix hash changes with the slug, so a new slug is a new queue
name and the reservation does not apply. The failure message says which queue
and that it "existed too recently"; `explainFailure` in the provisioner
translates it into that instruction.

`test-sandbox` is blocked on this until roughly 09/09/26.

## Open

- **Nothing checks slug collision.** Two agents whose names slug to the same
  first thirteen characters would collide on every resource. The console
  derives silently and Terraform would report a name conflict late in an apply.
  Worth a check where the agent is created, against the slugs already
  published for that client.
