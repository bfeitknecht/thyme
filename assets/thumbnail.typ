// The package thumbnail: a miniature post in the `blog` preset whose single
// auto-height page lands near A4, so Typst Universe cards need not crop or
// overflow it. Keep the content small: if it outgrows one page, the release
// render fails loudly instead of silently cropping.
#import "@preview/thyme:0.1.0": *
#import blog: *

#show: post.with(
  title: [Kleene on One Page],
  subtitle: [The `blog` preset in miniature],
  author: "Ada Lovelace",
  monograph: "EWD-02",
  created: datetime(year: 2026, month: 10, day: 20),
  summary: [A one-page tour of the `blog` preset: sidenotes, theorem environments, native MathML, and styled code.],
  tags: ("semantics", "lattices"),
)

#epigraph(source: [Dana S. Scott, 1970])[
  Recursive definitions select the least fixed point of a continuous functional.
]

To give an unbounded `while` loop a meaning, interpret program states over a pointed partial order#sidenote[The bottom element $bot$ represents non-termination, not an erroneous machine state.] and compute fixed points of monotone transformers.

= Lattices & Scott Continuity <kleene-fp>

#definition[Pointed $omega$-CPO & Scott Continuity][
  A partial order $(D, subset.eq.sq)$ is an _$omega$-complete partial order_ ($omega$-CPO) with least element $bot in D$ if every ascending chain $d_0 subset.eq.sq d_1 subset.eq.sq dots.c$ admits a least upper bound $union.sq.big_(n >= 0) d_n in D$.
][
  A map $F : D -> D$ is _Scott-continuous_ when it preserves suprema of ascending chains. Every Scott-continuous map is automatically monotone#sidenote[Finite lattices satisfy the ascending chain condition automatically, so monotonicity alone implies continuity.].
]

#theorem[Kleene's Fixed-Point Theorem][
  Let $(D, subset.eq.sq, bot)$ be a pointed $omega$-CPO and $F : D -> D$ a Scott-continuous functional. Then the least fixed point $"lfp"(F)$ exists and equals
  $ "lfp"(F) = union.sq.big_(n = 0)^infinity F^n (bot). $
]

#proof[
  Monotonicity yields $F^n (bot) subset.eq.sq F^(n+1)(bot)$ by induction, so $d^* = union.sq.big_(n >= 0) F^n (bot)$ satisfies $F(d^*) = d^*$, and any pre-fixed point dominates every iterate.
]

= Loop Denotation & Finite Iteration

We compute $"lfp"(Phi)$ by worklist stabilization#footnote[Standard `#footnote[...]` calls are routed into the right margin, so proofs remain uninterrupted.]:

#zebraw(
  highlight-lines: (4,),
  ```rust
  pub fn lfp<D: Eq + Clone>(bot: D, step: impl Fn(&D) -> D) -> D {
      let mut cur = bot;
      loop {
          let next = step(&cur);
          if next == cur { return cur; }
          cur = next;
      }
  }
  ```,
)
