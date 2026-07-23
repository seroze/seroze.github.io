---
layout: post
title: "Understanding MinIO: My First Steps into S3-Compatible Object Storage"
date: 2026-07-23 00:00:00 +0530
categories: distributed-systems
tags: [object_storage, distributed_systems, minio]
author: "Seroze"
published: true
---

# Understanding MinIO: My First Steps into S3-Compatible Object Storage

While exploring distributed systems, I wanted to understand what **MinIO** actually is and why everyone describes it as an "S3-compatible object store." Instead of jumping straight into image uploads or AI applications, I decided to start with the fundamentals: uploading simple strings and building a small storage abstraction in Python.

This post summarizes the concepts that helped me build the correct mental model.

---

# What is MinIO?

MinIO is an **open-source object storage server** that implements the **Amazon S3 API**.

Think of it as:

- **Amazon S3** → Managed object storage service provided by AWS.
- **MinIO** → Self-hosted object storage that behaves like S3.

The nice part is that if your application talks to MinIO using the S3 API, moving to AWS S3 later usually only requires changing the endpoint and credentials.

---

# Setting up MinIO

The easiest way to run MinIO locally is using Docker.

```bash
docker run -d \
  --name minio \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=supersecretpassword \
  -v $(pwd)/data:/data \
  quay.io/minio/minio server /data --console-address ":9001"
```

A few interesting observations:

- Docker automatically downloads the image if it doesn't already exist locally.
- Mapping `/data` to a host directory keeps data persistent.
- `9000` exposes the S3 API.
- `9001` exposes the MinIO web console.

---

# Buckets

Buckets are the top-level namespace in object storage.

Examples:

```
images
documents
models
logs
```

Unlike files, you typically have only a handful of buckets in an application.

---

# Objects

Every bucket contains **objects**.

Each object consists of three parts:

- Key
- Data (bytes)
- Metadata

For example:

```
Bucket: notes

Key:
hello.txt

Data:
Hello World

Metadata:
Content-Type: text/plain
```

This immediately answers an important question:

> **MinIO stores bytes, not files.**

Whether those bytes represent:

- text
- images
- videos
- PDFs
- machine learning models

doesn't matter.

Everything is just bytes.

---

# The Mental Model

Initially I thought of MinIO as a key-value store.

That's close, but not entirely accurate.

A better mental model is:

```
Bucket
    │
    ├── Object
    │      Key
    │      Bytes
    │      Metadata
    │
    ├── Object
    └── Object
```

The key identifies the object.

The value is the raw bytes.

Metadata travels alongside the object.

---

# There Are No Real Directories

This was one of the biggest realizations.

Suppose we upload:

```
images/cat.png
images/dog.png
notes/todo.txt
```

It *looks* like folders exist.

Internally, MinIO simply stores three keys:

```
images/cat.png
images/dog.png
notes/todo.txt
```

The `/` character is just another character in the key.

Folders are an illusion created by clients like the MinIO UI or the AWS Console.

---

# Listing Objects by Prefix

If folders don't actually exist, how do applications list "everything inside a folder"?

The answer is **prefix matching**.

Suppose a bucket contains:

```
users/alice/photo.png
users/alice/resume.pdf
users/bob/avatar.jpg
users/bob/report.pdf
```

Calling:

```
list_objects(prefix="users/alice/")
```

returns:

```
users/alice/photo.png
users/alice/resume.pdf
```

Conceptually it's similar to:

```python
for key in all_keys:
    if key.startswith(prefix):
        yield key
```

Of course MinIO performs this efficiently internally, but this is the correct way to think about it.

This design enables patterns like:

- listing every file belonging to one user
- loading training datasets
- retrieving today's logs
- organizing machine learning checkpoints

Simply by choosing good key names.

---

# Designing Good Object Keys

The object key is part of your data model.

Examples:

```
company-42/user-17/avatar.png

logs/2026/07/22/app.log

datasets/train/image001.jpg

models/v2/checkpoint.pt
```

Because prefix queries are efficient, good key naming makes many operations almost trivial.

---

# Versioning

Without versioning:

```
upload hello.txt
```

later followed by

```
upload hello.txt
```

simply overwrites the original object.

The old contents are lost.

With versioning enabled:

```
hello.txt

Version 1
Version 2
Version 3
```

The latest version is returned by default, but older versions remain available.

Deletion also behaves differently.

Instead of physically removing the object, MinIO creates a **delete marker**.

This allows accidental deletions to be reversed.

Versioning is especially useful for:

- backups
- legal documents
- production configuration
- machine learning models
- audit trails

One way to think about versioning is that objects become **append-only**. Every modification creates a new immutable version instead of destroying the previous one.

---

# Building a Storage Abstraction

Instead of letting the application depend directly on the MinIO SDK, I built a small storage interface.

```python
class Storage:

    def upload(key: str, content: bytes):
        ...

    def download(key: str) -> bytes:
        ...

    def delete(key: str):
        ...

    def list_objects(prefix: str = ""):
        ...
```

The MinIO implementation simply fulfills this interface.

```
Application
        │
        ▼
Storage Interface
        │
        ▼
MinIOStorage
        │
        ▼
S3 API
        │
        ▼
MinIO
```

The benefit is that another implementation (AWS S3, local filesystem, Azure Blob Storage, etc.) can be swapped in without changing the application.

---

# Everything Is Bytes

One of the biggest conceptual takeaways was this:

```
"Hello"

↓

b"Hello"

↓

Object Storage
```

The exact same upload mechanism works for:

```
Image

↓

PNG bytes

↓

Object Storage
```

or

```
Machine Learning Model

↓

Serialized bytes

↓

Object Storage
```

The storage layer doesn't care what those bytes represent.

---

# Final Mental Model

I now think of MinIO like this:

```
Application
      │
      ▼
 Storage Interface
      │
      ▼
 S3 API
      │
      ▼
 Bucket
      │
      ├── Object
      │      ├── Key
      │      ├── Bytes
      │      └── Metadata
      │
      └── Object
```

There are no real directories.

Everything is an object.

Objects are identified by keys.

The contents are simply bytes.

Good key naming enables efficient prefix queries.

Versioning preserves history.

Once these ideas click, MinIO feels much less like a filesystem and much more like a distributed object database optimized for storing immutable blobs of data.
