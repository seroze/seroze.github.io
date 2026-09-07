---
layout: post
title: "[Agents] General guidelines on how to write your own agents"
date: 2026-09-07 00:00:00 +0530
categories: agents
tags: [agents, llm, agentic_workflows, human_in_the_loop, automation]
author: "Seroze"
published: true
---

You build the agentic workflow, you watch it do the thing once, and it works. That feels
like the finish line. It isn't. The moment you actually start using it you notice you're
sitting there babysitting: it does forty seconds of work, stops, asks you something,
waits, does another forty seconds, stops again. You've automated the typing and kept all
of the attention.

Getting from there to something you can walk away from is a separate piece of work, and
it is mostly not prompt engineering. It's two unglamorous activities: writing down facts
about yourself that the agent had no way to know, and reading logs of the runs where it
went wrong. This post is about how I think about that second phase, using a job
application agent as the running example because it produces every kind of interruption
in one workflow.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The first version is always human-in-the-loop

This isn't a design flaw, it's arithmetic. The agent starts with exactly what you handed
it — a prompt, a few tools, maybe a document or two. Everything outside that, it either
asks about or makes up. A well-behaved one asks. So version one of any workflow is a
conversation, not automation, and that's the correct starting state.

Take the job application agent. You give it your resume and a list of postings. It opens
a posting, reads the form, starts filling. Then it stops:

- What are your salary expectations?
- The form asks for gender, race and veteran status. How should I answer?
- Do you require visa sponsorship now or in the future?
- What's your notice period, and when could you start?
- There's a "why do you want to work here" box. What should go in it?

None of that is on your resume. A resume is a record of what you have done. Almost every
question a form asks that isn't on your resume is a question about what you *want* or who
you are on a government form, and there was never any chance the agent could infer it.

## Sort the interruptions into two piles

Every time the agent stops, it is stopping for one of two reasons, and they get opposite
treatment.

**Pile one: it's asking because it doesn't know.** Missing context. Fixable, and fixable
permanently.

**Pile two: it's asking because it shouldn't be the one deciding.** Consent, judgment,
policy, anything with your signature on it. Not fixable, and you don't actually want it
fixed.

The mistake I see people make (and made myself) is treating every stop as friction to be
engineered away. Roughly half of them are. The other half are the only thing standing
between you and a bad afternoon. The test I use is simple: if I answered this question
the same way a hundred times in a row, would I be comfortable never being asked again? If
yes, it's pile one. If I flinch even slightly, it's pile two.

Salary expectations, notice period, sponsorship status — I'd answer those identically a
hundred times. Clicking submit on an application with my name on it, a hundred times,
unwatched? No.

## Pile one: turn answers into memory

Every pile-one answer is a fact about you the agent didn't have. The fix is to put it
somewhere the agent reads on every run, and then never type it again.

It doesn't need to be sophisticated. A file the agent loads at the start of the run gets
you most of the way:

```yaml
# profile.yaml — the things my resume doesn't carry
compensation:
  target_base_inr: 4200000
  minimum_acceptable_inr: 3400000
  rule: "leave blank if the field is optional; if mandatory, give the target"
  never_disclose_current: true

work_authorization:
  needs_sponsorship_now: false
  needs_sponsorship_future: false

demographics:
  # Voluntary EEO questions on US applications.
  rule: "prefer not to say, unless the field is mandatory and has no such option"
  gender: "prefer not to say"
  veteran_status: "prefer not to say"

logistics:
  notice_period_days: 30
  earliest_start: "2026-10-15"
  locations_open_to: ["Bangalore", "remote"]
  relocation: "only for a significant raise"
```

Two things about the format matter more than the format itself.

It has to be readable and editable by you, because you will change it far more often than
the agent will read it. A YAML file you can open and fix in ten seconds beats a clever
embedding store you can't inspect.

And it should record the *rule*, not just the value. "prefer not to say unless the field
is mandatory" is a different fact from "male", and if you only store the second one, it
gets filled into the one form where you wanted the first. Most of the pile-one questions
are like this — the answer isn't a constant, it's a small conditional, and if you flatten
it to a constant you've traded an interruption for a silent wrong answer.

Whether this lives in a plain file, a memory tool the agent writes to itself, or a proper
store is an implementation detail. The rule that matters is: **answering the same question
twice is a bug.** The second time you type your notice period, stop what you're doing and
go write it down.

There's a pleasant side effect. Once the memory file exists, it becomes the actual spec of
the workflow. If you want to know what your agent is going to say on your behalf without
watching it work, you read that file. That's a much better artifact than a prompt.

## Pile two: leave it alone

Some interruptions are load bearing, and it's worth being precise about which.

The obvious ones are actions that are irreversible and outward facing. Submitting the
application, sending the email, making the payment. The cost of one wrong autonomous
submit is enormously higher than the cost of a confirmation click, and the asymmetry
doesn't go away just because the agent has been right forty times in a row. Having the
agent fill everything and stop at a queue of ready-to-submit drafts is not a failure of
automation. It's the design.

Then there are the stops that aren't yours to remove at all. A site can say, in its terms
or in a notice on the form itself, that automated agents shouldn't be submitting here.
Claude will decline to auto-submit on your behalf in the browser when the page says that,
and the correct response is not to go looking for a way around it. If your workflow only
works by ignoring that instruction, you don't have a workflow, you have a liability with a
scheduler attached. This shows up hardest in the regulated verticals — hiring, finance,
healthcare — where a human signature is doing legal work and an agent's click cannot
stand in for it.

And there's anything you're attesting to. "I certify the information above is true" is a
claim by you about you. Even if you would tick it every single time, somebody needs to be
able to say truthfully that a human ticked it.

So the honest goal was never zero human in the loop. It's this: the human is consulted
once per unit of work, at the end, on the one thing only a human can sign. If today you're
stopped fifteen times per application and fourteen of those are pile one, the win available
to you is fifteen down to one. That last one stays, forever, on purpose.

## Now go find where it fails

Here's the part that surprised me. Once the agent stops asking, it starts being wrong
quietly, and quiet wrongness is worse than interruption. The interruptions were doing
double duty: they were also how you noticed mistakes. You were watching so closely that
errors never got a chance to accumulate. Take the questions away and you've removed your
own monitoring.

So before you automate away the stops, instrument. Log every run — which posting, which
fields it filled with what, whether it finished, where it gave up. Then actually read the
failures, and bucket them, because the buckets need completely different fixes.

The ones I keep hitting:

**The page wasn't shaped the way the agent expected.** Greenhouse, Lever and Workday are
three different worlds, and Workday wants you to create an account before you can even see
the form. This is a coverage failure, not a reasoning failure, and no amount of prompt
tuning fixes it. Either you write a path per applicant tracking system, or you accept that
Workday postings get queued for you to do by hand. Both are legitimate; pretending the
generic path handles it is not.

**It had the fact and put it in the wrong field.** Target salary typed into "current
compensation" is the canonical version of this, and it's expensive. The fix is a sharper
description in the memory file — naming explicitly what must never be disclosed — rather
than a bigger model.

**It hit a genuinely new question.** New question, new pile-one fact, into memory it goes.
This bucket should shrink run over run. If it isn't shrinking, you're answering questions
in chat and not writing them down.

**It guessed instead of asking.** The dangerous bucket. It invents four years of
Kubernetes experience because a form demanded a number and nothing in memory had one. This
is exactly why you don't lean too hard on "stop asking me things" in the prompt — squeeze
the asking behaviour and you don't get an agent that knows more, you get an agent that is
confidently wrong. Say it plainly in the prompt: if the answer isn't in the profile and
isn't in the resume, ask; never estimate a fact about the user.

**Flakiness.** Rate limits, captchas, a slow page, a session that expired. Retries with
backoff, and a run that fails loudly rather than half-finishing.

Fix the biggest bucket first, with one exception: the guessing bucket goes to the front of
the queue regardless of how few instances it has, because its failures are the ones that go
out into the world with your name attached.

## The loop this all adds up to

The workflow you build is not the workflow you end up running. The sequence that gets you
from one to the other:

1. Build it and let it ask about everything. Don't suppress the questions early.
2. Run it by hand a handful of times, answering honestly, and write down every single
   question it asked.
3. Sort that list into the two piles. Missing context goes into the memory file. Judgment,
   consent and policy stops stay exactly where they are.
4. Rerun and count the interruptions. This number should fall off a cliff.
5. Now that it's quiet, start logging and reading the failures. Fix the largest bucket.
   Go back to step 4.

Steps 3 and 5 are where all the leverage is, and neither one is glamorous. One is writing
down facts about yourself. The other is reading logs. That's the actual job.

The metric I'd hold a workflow to at the end isn't how autonomous it is. It's: how many
times did it need me, and were those the times it *should* have needed me? One stop, at
the end, on the thing with my name on it, is a finished workflow. Zero stops means I built
something that will eventually sign my name to a guess.
