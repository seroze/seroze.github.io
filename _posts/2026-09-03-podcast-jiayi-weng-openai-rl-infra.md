---
layout: post
title: "[Podcast] Interview with Jiayi Weng — Post Training RL Infra at OpenAI"
date: 2026-09-03 00:00:00 +0530
categories: podcast
tags: [podcast, reinforcement_learning, openai, infrastructure, career, open_source]
author: "Seroze"
published: true
---

I watched all two hours of [WhynotTV Podcast #4](https://www.youtube.com/watch?v=I0DrcsDf3Os)
with Jiayi Weng (翁家翌), who joined OpenAI in 2022 as roughly its 280th employee
and built the post-training RL infrastructure that a lot of the models since
have been trained on. He also wrote [Tianshou](https://github.com/thu-ml/tianshou),
the PyTorch RL library, and was on the Forbes 30 Under 30 AI list in 2025.

These are my notes. He's an opinionated guy and most of what follows is his
opinion rather than settled fact, so read it that way.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## He got to informatics by accident {#olympiad}

He did math olympiad training up to middle school. Then his region simply ran
out of good math coaching, so he switched to informatics. He did make the
provincial math team, but that was more or less the end of that thread.

Informatics went better. He ended up at NOI — China's national informatics
olympiad — representing Fujian in 2015, and came away with a bronze. He was
candid that bronze was the bottom of his team, which is the sort of thing
people usually leave out of a bio. It was enough for Tsinghua.

Worth being precise here because it's easy to garble: this is NOI, the national
olympiad, not IOI, the international one.

## Tsinghua: minimum viable GPA {#tsinghua}

His undergrad strategy was to put in the minimum effort needed for a decent
CGPA and not a unit more. He graduated 17th of 158, which is top ten percent,
so the strategy worked — but the point is that he was explicitly not optimising
for it. Everything left over went elsewhere.

Some of it went into hacking, because he thought hacking was cool. He found a
bug in something and reported it.

Most of it went into open sourcing his coursework. He put up past materials and
homework solutions, on the argument that the information asymmetry between
students who happened to know a senior and students who didn't was arbitrary and
fixable — 信息平权, information equality, is the phrase he uses. Some of his
seniors disagreed, fairly loudly. He kept doing it, but only published the
portions that were genuinely fine to publish.

The same instinct shows up later in the visa appointment trackers he built
(tuixue / 签签堂), where the framing is that a piece of software can just be a
public service.

## How he picked RL {#picking-rl}

This part is very funny. He wanted to do research as an undergrad and asked
seniors for professor recommendations. They gave him three names. He assumed the
three names were in ranked order — they were not — and went to the first one.

He asked that professor for the big directions in AI worth betting on, and got
three: Bayesian methods and statistical thinking, GANs, and reinforcement
learning. He picked RL partly because he thought it was also about images.

He was wrong about the reason and right about the choice, which is how a lot of
careers actually go.

## MILA, MoE in 2019, and giving up on a PhD {#mila}

He spent the summer of 2019 at MILA, accepted by Yoshua Bengio's group shortly
before Bengio's Turing Award. The project was implementing mixture-of-experts on
a transformer — in 2019, which is early enough to sting in hindsight. It didn't
work out. He got a second-author paper out of it and a recommendation letter,
but not a PhD admission; the offer he got was for a masters, which is how he
ended up at CMU doing Computational Data Science on the systems track.

His conclusion from that: a PhD is not very useful if the goal is industry. What
matters is having real expertise in something the big labs actually need right
now — RL infra, LLM research, interpretability. He also stopped wanting to
publish papers for their own sake once that box was ticked, on the view that the
number of people doing genuinely meaningful research is small and he'd rather not
add to the pile.

There's an obvious selection effect in hearing this from someone who did fine
without one, and he'd probably admit that.

## GitHub stars as an admissions signal {#stars}

One of his professors described the signal he uses when picking students, in
order: CGPA, then research publications, then GitHub stars — a three-digit star
count being the bar.

Jiayi went for the third. Tianshou cleared that bar by a wide margin.

I like this bit because it's the one place where he explicitly picks his own
metric instead of the ones handed to him, and it sets up the awkward question
that comes later.

## The offers, and the interview {#offers}

He applied to about eighteen companies and got offers from Google, OpenAI,
NVIDIA, and OctoML. FAIR fell through for unrelated reasons.

He says he'd have taken OctoML over Google — a compiler startup over big tech —
because it was more interesting and he didn't want to be a cog in a wheel. That
tells you most of what you need to know about how he chooses.

The OpenAI interview was with John Schulman: three hours to implement an
algorithm end to end. He finished in two. During the demo a bug surfaced and he
fixed it live. Schulman told him the question had only been given to two people
before.

## "You can teach research to an engineer, but not engineering to a researcher" {#engineers}

He picked this up from a PhD student during his masters and repeats it as a
guiding belief.

Take it with a pinch of salt — it's a generic claim and there are obvious
counterexamples in both directions. But the operational version of it holds up
better than the sweeping version: at the scale these labs work at, every lab's
codebase has bugs, and the model that comes out the other end is largely
determined by who fixed the most of them. That's an engineering-quality
statement, not a research-taste one.

## Inside OpenAI: whoever has the best infra wins {#infra}

When he joined there was no post-training team as such. It was just called RL,
and John Schulman ran it. He says he was genuinely sad when Schulman left.

His central claim about the field is simple: the lab with the best RL and
pre-training infrastructure wins, because infrastructure quality translates
directly into experiments per unit time, and experiments per unit time is the
thing that actually compounds.

He also credits a specific culture shift. The team wasn't especially
process-oriented until they hired three people from Google, who brought a
playbook around metrics with them and pushed the team to treat the RL infra
itself as the thing to measure and improve. The company was around 280 people
when he joined and is somewhere near 3,000 now.

## Tianshou, and why libraries rot {#tianshou}

Tianshou was built to make RL algorithms comparable: the design goal was that
swapping in a new algorithm should touch around twenty lines. He rewrote the
library a second time to get there.

His diagnosis of why he had to is the most transferable thing in the episode.
A project decays as more people contribute code without a shared theme holding
it together. Each contribution is locally reasonable; the aggregate drifts;
eventually the abstraction that made the library worth using is gone. That's not
an RL problem, that's every library.

He's largely moved on from it now, because Tianshou targets toy environments and
LLM-scale RL is a different animal entirely.

He quotes "ideas are free, execution is not" often enough that it's clearly load-bearing.

## The ER trip {#health}

At some point he overworked himself badly enough to end up in the emergency
room. The doctor found nothing wrong with him. He started running 3km twice a
week afterwards — which he notes he couldn't manage in PE class at Tsinghua.

Small anecdote, and he doesn't dwell on it, but it's the only part of the
episode where the cost side of the ledger shows up at all.

## How he measures a life {#metric}

His stated metric: the number of people who will remember your name when you die.

The host pushes on this, and the push is fair. He rejects CGPA as a measure of a
person's worth and then adopts a metric that is also a single number, also
externally assigned, and arguably harder to opt out of. He doesn't fully resolve
it. He does connect it to how he thinks about his own future — buying options for
his later self, getting to financial independence, and then having to work out
what to actually want once the interesting technical problems are solved.

His read on AGI fits the same mood: the path looks increasingly deterministic to
him, an engineering pipeline with a clearer roadmap than it used to have. Which
is either reassuring or unsettling depending on what you were hoping the answer
would be.

## What he'd tell an undergrad today {#advice}

Asked whether he'd still recommend this route, he says ML infra is still hot and
isn't going away soon, given how large the context and the systems have become.
His qualifier is that if you're running one-off experiments the infra doesn't
matter much, but at large-scale RL it does.

I'll be honest: I didn't fully follow what he meant there, and I think a concrete
example would have made the point land. My best guess is that a single
experiment can survive bad infra because you only pay the cost once, whereas at
scale the cost is paid per experiment and compounds into a throughput gap between
labs. But that's me filling in a blank he left.

One more observation from him: fewer Tsinghua students are leaving for graduate
school in the US than before, with more choosing to stay and do research
domestically.

## What I took from it {#takeaways}

Three things stuck.

Infrastructure is the bottleneck, and it's a research bottleneck, not a plumbing
one. Whoever runs more experiments per week learns faster, and that shows up in
the weights.

Picking your own metric is the actual skill. He chose GitHub stars over
publications, OctoML over Google, and open sourcing over hoarding — each time
against the local consensus. Whether the specific metric was right matters less
than the fact that he chose it deliberately.

And most of the good decisions in the story were made for partly wrong reasons.
He picked RL because he misread a list and misunderstood what RL was. It worked
anyway. Careers tolerate more noise than they look like they do from outside.
