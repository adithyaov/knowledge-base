---
title:      "Notes on hs-opentelemetry"
date:       2025-03-29T19:48:49+05:30
tags:       ["blog", "docs"]
identifier: "20250329T194849"
---

```callout
This is my understanding of a few internals. This information may need to be
corrected.

These are scratch notes that need to be reorganized later.
```

TraceProvider
=============

The entire flow starts with a `TraceProvider`. This is initialized at the root
level. This has the context of **how to deal with a Span**.

It has a list of `SpanProcessor` (`[SpanProcessor]`) that every `Span` gets
piped through. More on this later.


Tracer
======

The API in `hs-opentelemetry` takes a common argument called `Tracer`. A
`Tracer` is a wrapper over the `TraceProvider`. It also has information about
the package name.

```haskell
data Tracer = Tracer
    { tracerName :: !InstrumentationLibrary
    , tracerProvider :: !TracerProvider
    }
```

Multiple `Tracer` would share the same `TraceProvider`. `Tracer` serves to add
more information about where the `Span` originates from.

Span
====

Instrumenting code means defining proper `Span` structures over code blocks of
interest.

Looking at the lower level API gives a better understanding of what's under the
hood and how we can use the library properly.

Low level helpers to play with `Span`:
- `createSpanWithoutCallStack` (Read as `startSpan`)
- `endSpan`

The current `Span` that runs is associated with a haskell `Thread`. The context
of the running `Span` is saved in the thread local
storage. ([https://hackage.haskell.org/package/thread-utils-context][thread-utils-context](thread-utils-context))

At any point of time, there is only **one** `Span` in the current context. When
a child `Span` to starts, the parent `Span` is taken out of the current context
and the child `Span` is inserted. Once the child `Span` ends, the child span is
removed from the current context and the parent span is re-inserted.

We save the current context is to propagate the state to the child `Span` when
it is created.

Implications of using thread local storage
------------------------------------------

Forking a thread means we lose the current context on the forked thread. If we
want to instrument in a forked thread we have to somehow propagate the current
context to the forked thread.

```callout
Please note that not propagating the context **isn't incorrect**. There is loss
of relationship information but this isn't a correctness issue.
```

To do this, we need to make instrumentation a first class citizen while forking.
Concurrent `streamly` combinators that create threads should have the idea of
instrumentation.


Span Wrapper
------------

Let's create a simple wrapper using low level APIs to understand how to use
them.

```haskell
wrapSpan
     Tracer
  -> Text
  -> IO a
  -> IO a
wrapSpan tracer spanName action = do
    ctx <- getContext
    s <- createSpanWithoutCallStack tracer ctx spanName defaultSpanArguments
    adjustContext (insertSpan s)
    action
    endSpan s Nothing
    adjustContext $ \ctx ->
        case lookupSpan ctx of
            Nothing -> removeSpan ctx
            Just parent -> insertSpan parent ctx
```

This is a very simple span that wraps any `IO` action. We can be more clever and
handle errors and make this more robust.

`hs-opentelemetry` already does the hard work and provides robust combinators
such as `inSpan''`, `inSpan'`, etc.
