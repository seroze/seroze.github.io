---
layout: post
title: "Reinforcement Learning Part-1"
date: 2026-06-14 00:00:00 +0530
categories: machine-learning
tags: [reinforcement-learning]
author: "Seroze"
published: true
---

*Notes from studying Sutton & Barto and David Silver's lectures.*

---

## What is Reinforcement Learning?

Reinforcement Learning (RL) is about learning through interaction. An agent repeatedly:

1. Observes the environment.
2. Takes an action.
3. Receives a reward.
4. Observes the resulting state.

The objective is **not** to maximize immediate rewards but to maximize **cumulative future reward**.

Unlike supervised learning:
- There are no labels.
- There is no teacher providing the correct action.
- The agent must discover good behavior through trial and error.

---

## The RL Framework

An RL system consists of two entities:

**Agent** — the decision maker.  
Examples: chess engine, robot, trading system.

**Environment** — everything outside the agent.  
Examples: chess board, physical world, financial market.

The interaction loop:

```
State
  ↓
Agent chooses Action
  ↓
Environment responds
  ↓
Reward + Next State
```

---

## States and the Markov Property

A state should contain enough information to predict the future. This leads to the **Markov Property**:

$$P(S_{t+1} \mid S_t) = P(S_{t+1} \mid S_1, \ldots, S_t)$$

Intuitively: given the current state, the past no longer matters.

A useful analogy from distributed systems is a **replicated state machine** — once the log has been applied, the current state is sufficient; the entire history is no longer needed to determine future behavior.

---

## Markov Decision Process (MDP)

Most classical RL assumes the environment is a **Markov Decision Process**, defined by:

$$\langle \mathcal{S}, \mathcal{A}, P, R, \gamma \rangle$$

| Symbol | Meaning |
|--------|---------|
| $\mathcal{S}$ | States |
| $\mathcal{A}$ | Actions |
| $P$ | Transition probabilities |
| $R$ | Reward function |
| $\gamma$ | Discount factor |

---

## Rewards vs Returns

**Reward** measures immediate feedback:

| Outcome | Reward |
|---------|--------|
| Win game | +1 |
| Lose game | -1 |
| Draw | 0 |

RL optimizes **return**, not reward. Return is the discounted sum of future rewards:

$$G_t = R_{t+1} + \gamma R_{t+2} + \gamma^2 R_{t+3} + \cdots$$

---

## Discount Factor

$\gamma$ controls how patient the agent is.

- $\gamma = 0$ — only cares about immediate reward.
- $\gamma \approx 1$ — values long-term outcomes.

This maps naturally to engineering organizations:
- Low $\gamma$ → optimize quarterly metrics.
- High $\gamma$ → invest in long-term infrastructure and reliability.

---

## Value Functions

A value function answers: **how good is this state?**

$$V(s) = \mathbb{E}\left[\sum_{k=0}^{\infty} \gamma^k R_{t+k+1} \;\middle|\; S_t = s\right]$$

A state can have immediate reward = 0 yet very high value. In chess, a position may have no immediate reward while being one move away from a forced win.

> **Reward is a fact. Value is a prediction.**

---

## Action-Value Functions

Sometimes we care about specific actions rather than states. This gives us $Q(s, a)$:

$$Q(s, a) = \mathbb{E}\left[G_t \mid S_t = s, A_t = a\right]$$

Example:

```
Q(s, Attack) = 80
Q(s, Defend) = 30
→ Choose Attack
```

A policy can be derived directly from Q-values:

$$\pi(s) = \arg\max_a \; Q(s, a)$$

---

## Relationship Between V and Q

If we know all Q-values:

$$V(s) = \max_a \; Q(s, a)$$

Q-values contain more information than state values — they tell us how good every action is, not just the best achievable value. The chain is:

$$Q\text{-values} \;\rightarrow\; V\text{-values} \;\rightarrow\; \text{Policy}$$

---

## Bellman's Key Insight

The most elegant idea in RL: the value of a state can be expressed **recursively**.

Return satisfies:

$$G_t = R_{t+1} + \gamma G_{t+1}$$

Which gives the **Bellman equation**:

$$V(s) = \mathbb{E}\left[R_{t+1} + \gamma V(S_{t+1}) \mid S_t = s\right]$$

In words:

$$\underbrace{V(s)}_{\text{Value now}} = \underbrace{R}_{\text{Reward now}} + \underbrace{\gamma \cdot V(s')}_{\text{Discounted future value}}$$

This recursive structure is the foundation of:
- Dynamic Programming
- TD Learning
- SARSA, Q-Learning
- Value Iteration, Policy Iteration

Most classical RL is just different ways of solving or approximating Bellman equations.

---

## Key Takeaway

The biggest shift in thinking: **RL is not about maximizing immediate rewards — it is about reaching valuable future states.**

A move with zero immediate reward can be better than a move with a positive reward if it leads to a significantly better future.

That single idea motivates value functions, Bellman equations, planning, and much of reinforcement learning itself.
