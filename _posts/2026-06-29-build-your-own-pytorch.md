---
layout: post
title: "Build Your Own PyTorch — Understanding Deep Learning Frameworks From the Inside Out"
date: 2026-06-29 00:00:00 +0530
categories: machine-learning
tags: [pytorch, deep-learning, autograd, from-scratch, systems]
author: "Seroze"
published: true
---

*PyTorch is a powerful abstraction, but it can feel like magic until you've built something like it yourself. This post walks through the core ideas behind implementing a minimal PyTorch clone — tensors, automatic differentiation, modules, and optimizers — so you understand what's actually happening under the hood when you call `loss.backward()`.*

*The best companion resource I've found for this is [TinyTorch from the ML Systems book](https://mlsysbook.ai/tinytorch/preface.html) — a from-scratch implementation that strips PyTorch down to its essential ideas.*

---

## Why build it yourself?

You can use PyTorch effectively without understanding its internals. But when things go wrong — silent gradient bugs, unexpected memory usage, broken custom layers — you're flying blind.

Building a minimal version forces you to answer questions like:

- What is a tensor, really?
- How does calling `.backward()` know which operations to differentiate through?
- What does `nn.Module` actually do when you subclass it?
- Why does `optimizer.zero_grad()` need to exist at all?

Once you've answered these, the whole framework feels obvious rather than magical.

---

## The four layers of PyTorch

A minimal implementation has four pieces, each building on the last:

```
Tensor              — N-dimensional array + metadata
  ↓
Autograd            — tracks operations to compute gradients
  ↓
nn.Module           — composable, parameter-owning building blocks
  ↓
Optimizer           — updates parameters using gradients
```

---

## Layer 1: Tensor

A tensor is just a multi-dimensional array with a shape and a dtype. The simplest implementation wraps a NumPy array:

```python
class Tensor:
    def __init__(self, data, requires_grad=False):
        self.data = np.array(data, dtype=np.float32)
        self.requires_grad = requires_grad
        self.grad = None
        self._grad_fn = None   # set by autograd
```

The `_grad_fn` pointer is the key — it connects each tensor back to the operation that produced it, forming the computational graph.

---

## Layer 2: Autograd — the computational graph

Every operation on a tensor creates a new tensor and records *how* it was created. This chain of operations is the **computational graph**.

For addition:

```python
def __add__(self, other):
    out = Tensor(self.data + other.data, requires_grad=True)
    
    def _backward():
        if self.requires_grad:
            self.grad += out.grad          # d(a+b)/da = 1
        if other.requires_grad:
            other.grad += out.grad         # d(a+b)/db = 1
    
    out._grad_fn = _backward
    return out
```

Calling `.backward()` on the loss does a reverse topological traversal of the graph, calling each `_grad_fn` in order:

```python
def backward(self):
    self.grad = np.ones_like(self.data)   # seed gradient = 1
    
    topo = []
    visited = set()
    
    def build_topo(t):
        if t not in visited:
            visited.add(t)
            for child in t._children:
                build_topo(child)
            topo.append(t)
    
    build_topo(self)
    
    for t in reversed(topo):
        if t._grad_fn:
            t._grad_fn()
```

The gradient of each tensor accumulates via the chain rule as the traversal unwinds.

### Key operations to implement

| Operation | Forward | Backward (grad w.r.t. input) |
|---|---|---|
| `add` | `a + b` | `1`, `1` |
| `mul` | `a * b` | `b`, `a` |
| `matmul` | `A @ B` | `grad @ B.T`, `A.T @ grad` |
| `relu` | `max(0, x)` | `grad * (x > 0)` |
| `sum` | `Σ x` | broadcast `grad` back |
| `log` | `log(x)` | `grad / x` |
| `exp` | `e^x` | `grad * e^x` |

These seven cover a surprising fraction of real networks.

---

## Layer 3: nn.Module

`nn.Module` is a container for parameters and sub-modules. Its job is to:

1. Track all `Parameter` tensors recursively.
2. Provide a `__call__` method that runs `forward`.
3. Enable `.parameters()` iteration for the optimizer.

```python
class Module:
    def __call__(self, *args):
        return self.forward(*args)
    
    def parameters(self):
        for name, val in self.__dict__.items():
            if isinstance(val, Parameter):
                yield val
            elif isinstance(val, Module):
                yield from val.parameters()
    
    def zero_grad(self):
        for p in self.parameters():
            p.grad = np.zeros_like(p.data)
```

A linear layer built on this:

```python
class Linear(Module):
    def __init__(self, in_features, out_features):
        self.weight = Parameter(np.random.randn(in_features, out_features) * 0.01)
        self.bias = Parameter(np.zeros(out_features))
    
    def forward(self, x):
        return x @ self.weight + self.bias
```

And stacking layers into an MLP:

```python
class MLP(Module):
    def __init__(self):
        self.fc1 = Linear(784, 128)
        self.fc2 = Linear(128, 10)
    
    def forward(self, x):
        x = relu(self.fc1(x))
        return self.fc2(x)
```

`parameters()` recurses into `fc1` and `fc2` automatically.

---

## Layer 4: Optimizer

The optimizer reads the accumulated `.grad` on each parameter and updates `.data`. SGD is two lines:

```python
class SGD:
    def __init__(self, params, lr=0.01):
        self.params = list(params)
        self.lr = lr
    
    def step(self):
        for p in self.params:
            if p.grad is not None:
                p.data -= self.lr * p.grad
```

This is why `zero_grad()` exists: gradients accumulate by default (so you can do gradient accumulation across mini-batches). You must clear them manually between steps.

---

## Putting it together: a training loop

```python
model = MLP()
optimizer = SGD(model.parameters(), lr=0.01)

for x_batch, y_batch in dataloader:
    # forward
    logits = model(x_batch)
    loss = cross_entropy(logits, y_batch)
    
    # backward
    model.zero_grad()
    loss.backward()
    
    # update
    optimizer.step()
```

This is identical to the PyTorch training loop — because PyTorch's loop is just a more robust, GPU-accelerated version of exactly this.

---

## What TinyTorch covers

The [TinyTorch section of the ML Systems book](https://mlsysbook.ai/tinytorch/preface.html) works through this implementation systematically, from raw tensors up through a working MNIST classifier. It's the clearest guided path I've seen through these ideas.

The progression:

1. **Tensor basics** — shape, dtype, basic ops
2. **Autograd from scratch** — building and traversing the compute graph
3. **Activations and loss** — relu, softmax, cross-entropy
4. **nn.Module** — composable layer abstraction
5. **Optimizers** — SGD and Adam
6. **Training loop** — putting it all together

If you've used PyTorch but never understood what `.backward()` actually does, working through TinyTorch is the fastest way to close that gap.

---

## Things you learn that PyTorch hides

- Gradient accumulation is the *default* — zero_grad isn't a quirk, it's a feature.
- The computational graph is rebuilt every forward pass (in eager mode). This is why you can use Python control flow freely.
- `requires_grad=False` is a critical optimization: leaf tensors that don't need gradients (like input data) should never enter the graph.
- Broadcasting in backward passes is non-trivial — when NumPy broadcasts during a forward op, the backward must sum gradients along broadcasted dimensions.

---

## Next steps

Once your toy implementation trains MNIST:

- Add **Adam** (needs per-parameter first and second moment tracking)
- Add **batched operations** and verify gradients with finite difference checks
- Read the [PyTorch autograd internals docs](https://pytorch.org/docs/stable/notes/autograd.html)
- Look at [micrograd](https://github.com/karpathy/micrograd) by Andrej Karpathy — a scalar-valued autograd engine in ~150 lines

The goal isn't to replace PyTorch. It's to understand it well enough that you can debug it, extend it, and trust it.
