# What a BRICK Is

BRICK stands for Building block, Role, Implementation, Configuration, Kit. These five letters are not types of artifacts. They are registers, five lenses through which every typed artifact in the platform is viewed. BRICK is the universal grammar of platform artifacts. Types (`#Service`, `#Database`, `#Pipeline`, whatever you define) are the vocabulary. Every type, no matter what it is, has all five registers.

---

## The Five Registers

Building block is structural. A block is a directory with a BUILD file. It is the atom, the encapsulation boundary that says "this is a thing." Block does not care what the thing is or what it does. It draws the boundary. Git is the catalog of blocks: each commit hash is an identity, `bazel query` is the query interface, Sigstore and git history provide versioning and signing. There is no separate registry. The repo is the registry.

Role is denotational. What this block means: its CUE schema, its type contract, its interface definition. Role specifies what the block is as a mathematical object, independently of how it is produced. Role is declared before anything is built. A `#Service` Role says "this thing must have a port, a name, and replicas satisfying these constraints." Role answers: what must this satisfy?

Implementation is operational. What the build produced: the binary, the container image, the manifest, the Bazel output. Implementation is meaning given by execution. Role says what the block should be; Implementation says what it actually is after Bazel ran. Implementation answers: what artifact exists?

Configuration is compositional. The concrete bindings that wire one block into another. Configuration is always a file you can point to in git: a Helm values.yaml, a CUE overlay, Terraform input variables, an ArgoCD Application spec, a Bazel `deps` attribute. Configuration is the glue, the actual key-value pairs that make one block's Role become another block's dependency. Configuration answers: how is this thing attached to that thing? Without Configuration, Kit is an abstract graph. Without Kit, Configuration is untyped glue. Together: typed relations with concrete bindings, all in git, all diffable, all constrainable by CUE.

Kit is categorical. The block's full relational context, how it relates to everything it touches, in every direction.

Upward: how this block relates to the whole ("I am a component in this service mesh"). Downward: how this block relates to its parts ("I compose these three blocks according to these typed relations"). Lateral: how this block relates to peers ("My output satisfies your input contract"). Temporal: how this block relates across stages ("I become the next thing in the chain").

Kit is not the graph (that is topology). Kit is the semantics of the graph: the typed meaning of every connection, with witnesses that prove the connections are well-typed. Kit is present on every block. A leaf block's Kit only points upward (it participates in wholes but does not compose parts). A composite block's Kit points both up and down. The register is always there; its contents vary.

---

## Registers, Not Types

BRICK letters are the rules. Types are whatever you decide.

The relationship between types is Kit. The connection between types is Configuration. Every type has an Implementation, a Role, and a directory (Block).

| Register          | Governs                                | You Define                                          |
| ----------------- | -------------------------------------- | --------------------------------------------------- |
| B, Block          | Every type has a directory             | Which directories exist, what they are called       |
| R, Role           | Every type has a denotational contract | The CUE schemas: `#Service`, `#Pipeline`, `#Potato` |
| I, Implementation | Every type has an operational artifact | What Bazel produces: binary, image, manifest        |
| C, Configuration  | Types connect via bindings             | Helm values, CUE overlays, Terraform inputs         |
| K, Kit            | Types relate via categorical structure | Dependency graphs, temporal chains, part/whole      |

A concrete example:

```
#Service    B: //services/payments/   R: #Service schema   I: Go binary + image   C: Helm values    K: part of #Mesh, depends on #Database
#Database   B: //infra/postgres/      R: #Database schema  I: TF module           C: TF vars         K: part of #DataStack, serves #Service
#Pipeline   B: //pipelines/etl/       R: #Pipeline schema  I: Babashka script     C: CUE overlay     K: raw->cleaned->enriched->loaded (temporal)
```

Every type, no matter what it is, has all five registers. BRICK is the meta-structure. Types are instances.

---

## The Temporal Dimension

Kit captures temporal relationships (what becomes what) in addition to spatial ones (what connects to what).

Consider a data preparation pipeline:

```
raw_potato -> diced_potato -> boiled_potato -> ingredient_in_dish
```

Each stage is a block. Each arrow is a Kit relation, typed and directed, with interface contracts at every boundary. `diced_potato` satisfies the Interface that `boiled_potato`'s Role requires as input. The Kit does not just say "these are connected." It says "this transformation produces an output that satisfies the next stage's input contract."

The temporal ordering is not declared explicitly. It falls out of the typed dependencies. You cannot boil before you dice because `boiled_potato`'s Role requires `#Diced` as input, and `raw_potato` does not satisfy `#Diced`. The constraint surface enforces temporal ordering as a consequence of type satisfaction.

This composes across scales: the potato chain is itself a Kit (a prep pipeline), which participates in a larger Kit (the dish), which participates in a larger Kit (the meal). At every level, the structure is the same: typed inputs, typed outputs, interface contracts at boundaries.

---

## The Fixed-Point Property

BRICK is both beginning and end. Role defines the contract before the build. Implementation is the artifact that satisfies the contract after the build. The fixed point is where they agree:

```
CUE schema (Role) contains Bazel output (Implementation)
```

At the block level, this is a proof that denotational and operational semantics are consistent. The CUE schema said "this is what it must be." Bazel produced an artifact. CUE unification confirms the artifact satisfies the schema. The committed file in git is the constructive witness, the concrete object anyone can inspect to verify it.

At the system level, Kit structure composes these proofs: every block's Role is satisfied by its Implementation, every Configuration binds correctly, every Kit relation is well-typed. The system is a proof tree. Each block is a leaf lemma, the composed system is the theorem.

The proof composes across scales. A valid composed block can itself be a Building block in a larger composition. A service becomes part of a mesh becomes part of an environment becomes part of a platform. Each level is a BRICK with all five registers, and the fixed-point property holds at every level.

---

## The Paved Road

All development is brick development. A Terraform module, a Go service, a data pipeline, a policy document: they all have a directory (B), a schema (R), a build output (I), configuration bindings (C), and a position in the dependency graph (K). The five registers apply uniformly regardless of language, runtime, or domain.

| Register           | Any Brick                          |
| ------------------ | ---------------------------------- |
| B (Block)          | A directory with a BUILD file      |
| R (Role)           | A CUE schema defining the contract |
| I (Implementation) | A Bazel-built artifact             |
| C (Configuration)  | Bindings wiring it to other bricks |
| K (Kit)            | Categorical context in the system  |

The contents of the brick, what language it is written in, what runtime it targets, what logic it encodes, are the developer's and the agent's concern. The BRICK registers constrain the structure, not the interior. What happens inside the brick boundary is free.

The BRICK registers, combined with `bazel build` and CUE schemas, define a paved road through the monorepo. Any brick on the road gets zero-context agent loading (BRI implicit in the build, CK in the schema), lazy-loaded diagnostics (contract violations point the agent to the exact brick), composability (Kit relations are typed and verified), and the fixed-point proof (Role contains Implementation, checked mechanically).

Getting on the road requires satisfying the five registers. Staying on the road requires keeping them satisfied. The road does not restrict what you build or how you build it. It restricts the interface between what you build and the rest of the system.

Nothing enters the composed system without all five registers being satisfied: a directory exists (B), a contract is declared (R), an artifact is produced (I), bindings are specified (C), and categorical context is well-typed (K).

---

## Midas Bricks: Archetypes That Reduce Definition

Most bricks of a given type look similar. Most Go services need a port, a health check, an SLO, environment variables, and a mesh position. Writing the full BRICK register set from scratch for each one is wasteful.

A Midas brick is an archetype: a fully specified BRICK that new bricks inherit from. It defines the Role schema, the default Configuration bindings, the Kit relations, and the BUILD rules for its type. A new brick of that type inherits all of this and overrides only what differs.

```cue
// The Midas brick for Go services
#GoService: {
    port:        int & >0 & <65536
    healthCheck: string | *"/healthz"
    replicas:    int & >=1 & <=100 | *3
    slo:         #SLO | *#SLO & {availability: 0.999}
    mesh:        #MeshConfig | *#MeshConfig & {enabled: true}
}

// A new service brick: specify only the delta
myService: #GoService & {
    port: 8080
    slo: availability: 0.9999
}
```

The Midas brick encodes expert knowledge structurally. A platform engineer builds `#GoService` once, with careful defaults, comprehensive constraints, and good documentation. Every new Go service brick inherits from it. The new brick's author specifies only the delta: what makes this service different from the archetype.

Midas bricks compose with the zero-context agent loading story. The agent reads the Midas brick's schema (one document per type) and knows the full contract for every brick of that type. New bricks that inherit from the Midas brick need no additional schema documentation. The agent context cost for a new brick is zero beyond what it already loaded for the type.

The name comes from the property: everything the Midas brick touches becomes a brick. Point a directory at a Midas brick, override the delta, and `bazel build` produces a fully registered, schema-validated, composable BRICK.

The Midas brick constrains structure, not implementation. A `#GoService` Midas brick says "you must have a port, a health check, and an SLO." It does not say "use this HTTP framework" or "your handler functions must have this signature." Those are implementation choices. The developer or agent makes them freely inside the brick boundary.

---

## Zero-Context Agent Loading

The five registers split into two groups with different context-loading characteristics.

BRI (Block, Role, Implementation) is implicit in `bazel build`. One command, run in any directory, and the build system already knows the directory boundary (B), evaluates the CUE schema (R), and produces the artifact (I). No human-written context is needed for these three registers. The agent does not need to be told about them; the build system embeds them. BRI costs zero tokens of agent context for every brick in the system.

CK (Configuration, Kit) are pointers into schema documentation. Configuration says "here is how this brick binds to others." Kit says "here is how this brick relates to the whole." Both live in CUE schemas, which carry their own documentation. The agent reads the schema, gets the structural contracts, and knows where a brick fits without ever opening the brick's internals. Because CUE schemas are shared across all bricks of a given type, the CK documentation is written once and reused everywhere. A single `#Service` schema with good documentation covers every service brick in the monorepo.

The context loading story for an agent working on any brick:

1. `bazel build` in a directory. BRI is resolved. Zero human-written context loaded.
2. Agent reads the CUE schema for C and K. Gets the structural contracts: what this brick connects to, how it relates to the whole. This is a small, reusable document.
3. The agent now knows the brick's position in the system without having loaded any brick-specific internals.
4. Only when a structural contract is violated (a CUE unification failure, a Kit relation that does not type-check) does the agent lazy-load the brick's details to diagnose and fix the problem.

For enormous infrastructure (thousands of bricks), the agent's context at any moment contains only the schema documentation (reusable across all bricks of that type) plus the specific bricks whose contracts are currently violated. Everything else stays on disk. The structural contracts are the index. You scan the index cheaply and only pull the full record when the index says something is wrong.

This inverts the conventional approach to agent context management. Instead of pre-loading everything the agent might need (which scales with infrastructure size and blows the context window), the platform pre-computes structural contracts via `bazel build` + CUE schemas, and the agent loads brick internals lazily, on violation, at the exact precision of the broken contract. The quality of CUE schema documentation directly determines agent effectiveness: good schema docs with clear contract descriptions mean the agent can navigate the entire infrastructure from schema alone.

---

## No Per-Directory Agent Instructions

A common pattern in agent-assisted codebases is a per-directory agents.md file that tells the agent what a directory contains, how to work with it, and what to avoid. This is human-written context compensating for the absence of machine-readable contracts. If CUE schemas carry documentation (field comments, constraint descriptions, relationship pointers), the schema is the agents.md for every brick of that type. A per-directory agents.md duplicates what the schema already says, and it drifts the moment someone updates the schema without updating the markdown.

What remains necessary is one root-level agents.md that covers what CUE schemas cannot express: monorepo conventions not encoded in any single schema, the BRICK register model itself (so the agent knows how to read schemas), which `bazel` commands to run, how to interpret test failures across layers, and any org-specific workflow rules (PR process, approval gates). This is a small, stable document that bootstraps the agent into the system. Everything else the agent discovers by reading schemas and running builds.

The root agents.md is the bootloader. CUE schemas are the operating system. Brick internals are userspace, loaded on demand. The bootloader is written once by a human and changes rarely. The operating system (schemas) is maintained as part of normal platform work, and its documentation is authoritative because it is co-located with the constraints it documents. Userspace (brick internals) is never pre-loaded; the agent enters it only when a contract violation points there.

---

## Summary

BRICK is five registers on every platform artifact:

| Register          | Formal Home   | Question It Answers   |
| ----------------- | ------------- | --------------------- |
| B, Building block | Structural    | What is the unit?     |
| R, Role           | Denotational  | What must it satisfy? |
| I, Implementation | Operational   | What artifact exists? |
| C, Configuration  | Compositional | How is it attached?   |
| K, Kit            | Categorical   | How does it relate?   |

The letters are the rules. Types are the vocabulary. The fixed point (Role contains Implementation) is the proof of consistency. Kit composes these proofs across scales. The git repo is the witness.
